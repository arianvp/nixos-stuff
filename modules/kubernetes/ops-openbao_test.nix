# Exercises the procedures of runbooks/openbao.md against a three node OpenBao
# raft cluster bootstrapped from SPIRE, as the kubernetes test sets it up.
# Subtests that show a weakness assert the current behaviour and say why it is
# bad, so that they fail once it is fixed.
{ pkgs, lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };
  fqdn = name: "${name}.${t.domain}";

  openbaos = [
    "openbao1"
    "openbao2"
    "openbao3"
  ];
  # The new machine of "Replace a member with a new machine", outside the
  # round-robin name
  spare = "openbao4";

  # A real key would be encrypted with systemd-creds
  sealKey = pkgs.writeText "openbao-seal-key" "6b2c5f2a2a4e4c1f9d3e7b8a0c1d2e3f4a5b6c7d8e9f00112233445566778899";
  newSealKey = pkgs.writeText "openbao-seal-key-2" "a1b2c3d4e5f60718293a4b5c6d7e8f90112233445566778899aabbccddeeff00";

  openbao =
    name:
    { lib, ... }:
    {
      spire.openbao = {
        enable = true;
        spiffeID = "spiffe://${t.trustDomain}/openbao/${name}";
        managers = map (n: "spiffe://${t.trustDomain}/openbao/${n}") (openbaos ++ [ spare ]);
        bootstrap = name == lib.head openbaos;
        retryJoin = map (n: "https://${fqdn n}:8200") (lib.remove name openbaos);
        sealKey.file = "${sealKey}";
        autopilot = {
          minQuorum = lib.length openbaos;
          deadServerLastContactThreshold = "1m";
        };
        policies.admin = ''
          path "*" {
            capabilities = ["create", "read", "update", "delete", "list", "sudo"]
          }
        '';
        certRoles.admin = {
          allowedURISANs = [ "spiffe://${t.trustDomain}/k8s/admin/root" ];
          policies = [ "admin" ];
        };
      };
      kubernetes.spire.entries."${name}-openbao" = {
        spiffeID = "spiffe://${t.trustDomain}/openbao/${name}";
        selectors = [ "systemd:id:openbao-svid.service" ];
        dnsNames = [
          (fqdn name)
          "openbao.${t.domain}"
        ];
      };
      # The transit keys and roles of a real cluster
      kubernetes.encryption = {
        enable = true;
        openbao = "https://openbao.${t.domain}:8200";
      };
      kubernetes.kube-jwt-signer = {
        enable = true;
        openbao = "https://openbao.${t.domain}:8200";
      };

      specialisation.seal-rotate.configuration.spire.openbao.sealKey = {
        file = lib.mkForce "${newSealKey}";
        id = lib.mkForce "2";
        previous = {
          file = "${sealKey}";
          id = "1";
        };
      };
      specialisation.seal-new.configuration.spire.openbao.sealKey = {
        file = lib.mkForce "${newSealKey}";
        id = lib.mkForce "2";
      };
    };
in
{
  name = "ops-openbao";
  globalTimeout = 900;

  defaults =
    { nodes, ... }:
    {
      imports = [ t.node ];
      networking.extraHosts =
        t.spireHosts nodes.spire
        + lib.concatMapStrings (
          n: "${nodes.${n}.networking.primaryIPv6Address} openbao.${t.domain}\n"
        ) openbaos;
      environment.systemPackages = [
        pkgs.curl
        pkgs.jq
      ];
    };

  nodes = {
    spire.imports = [ t.server ];
  }
  // lib.genAttrs (openbaos ++ [ spare ]) openbao;

  testScript =
    { nodes, ... }:
    let
      toplevels = lib.genAttrs openbaos (n: "${nodes.${n}.system.build.toplevel}");
    in
    ''
      import base64
      import json
      import re
      import time

      client = spire
      openbaos = [openbao1, openbao2, openbao3]
      toplevels = ${builtins.toJSON toplevels}
      ca = "/tmp/admin/bundle.0.pem"
      plaintext = base64.b64encode(b"ops-test").decode()
      server_cli = "-socketPath ${nodes.spire.services.spire.server.settings.server.socket_path}"

      def url(target, path):
          return f"https://{target}.${t.domain}:8200/v1/{path}"

      def curl(*args):
          return " ".join(["curl --silent --show-error --fail-with-body --max-time 10 --cacert", ca, *args])

      def fetch_svid():
          client.wait_until_succeeds(
              "mkdir -p /tmp/admin && spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write /tmp/admin > /dev/null",
              timeout=60,
          )

      def admin_token(target):
          """Logs in with the driver shell's SVID, spiffe://${t.trustDomain}/k8s/admin/root"""
          fetch_svid()
          out = client.wait_until_succeeds(
              curl("--cert /tmp/admin/svid.0.pem --key /tmp/admin/svid.0.key", body({"name": "admin"}), url(target, "auth/cert/login"))
              + " | jq -er .auth.client_token",
              timeout=60,
          )
          return out.strip()

      def body(obj):
          name = f"/tmp/body-{abs(hash(json.dumps(obj)))}.json"
          encoded = base64.b64encode(json.dumps(obj).encode()).decode()
          client.succeed(f"echo {encoded} | base64 -d > {name}")
          return f"--data @{name}"

      def bao_cmd(token, target, path, *args):
          return curl(f"-H 'X-Vault-Token: {token}'", *args, url(target, path))

      def bao(token, target, path, *args):
          out = client.succeed(bao_cmd(token, target, path, *args))
          return json.loads(out) if out.strip() else None

      def seal_status(target):
          return json.loads(client.succeed(curl(url(target, "sys/seal-status"))))

      def unsealed(target):
          return curl(url(target, "sys/seal-status")) + " | jq -e '.sealed == false'"

      def leader(target):
          return json.loads(client.succeed(curl(url(target, "sys/leader"))))

      def raft_servers(token, target):
          return bao(token, target, "sys/storage/raft/configuration")["data"]["config"]["servers"]

      def node_id(token, target, name):
          return next(s["node_id"] for s in raft_servers(token, target) if f"{name}." in s["address"])

      def node_ids(token, target):
          return sorted(s["node_id"] for s in raft_servers(token, target))

      def assert_derived(name, node):
          """The host name and 12 hex digits of the app-specific machine ID"""
          assert re.fullmatch(f"{name}-[0-9a-f]{{12}}", node), (name, node)

      def wait_healthy(target, timeout=120):
          """All nodes unsealed, three voters, autopilot healthy"""
          for m in openbaos:
              client.wait_until_succeeds(unsealed(m.name), timeout=timeout)
          token = admin_token(target)
          state = bao_cmd(token, target, "sys/storage/raft/autopilot/state")
          try:
              client.wait_until_succeeds(state + " | jq -e '.data.healthy and (.data.voters | length) == 3'", timeout=timeout)
          except Exception:
              print(client.execute(state + " 2>&1")[1])
              for m in openbaos:
                  print(client.execute(curl(url(m.name, "sys/leader")) + " 2>&1")[1])
              raise
          return token

      def encrypt_cmd(token, target, key="ops"):
          return bao_cmd(token, target, f"transit/encrypt/{key}", body({"plaintext": plaintext}))

      def encrypt(token, target, key="ops"):
          out = client.wait_until_succeeds(encrypt_cmd(token, target, key), timeout=60)
          return json.loads(out)["data"]["ciphertext"]

      def decrypt_cmd(token, target, ciphertext, key="ops"):
          return (
              bao_cmd(token, target, f"transit/decrypt/{key}", body({"ciphertext": ciphertext}))
              + f" | jq -e '.data.plaintext == \"{plaintext}\"'"
          )

      def check_transit(token, target, ciphertexts):
          ciphertext = encrypt(token, target)
          for c in ciphertexts + [ciphertext]:
              client.wait_until_succeeds(decrypt_cmd(token, target, c), timeout=60)
          return ciphertext

      def switch(machine, specialisation=None):
          path = toplevels[machine.name]
          if specialisation:
              path += f"/specialisation/{specialisation}"
          return machine.execute(f"{path}/bin/switch-to-configuration test 2>&1")

      def show(label, value):
          print(f"OBSERVED {label}: {json.dumps(value, sort_keys=True)}")

      def agents(m):
          out = client.succeed(f"spire-server agent list {server_cli} -output json")
          selector = {"type": "tpm", "value": f"model:{m.name}"}
          return [a for a in json.loads(out).get("agents", []) if selector in a["selectors"]]

      for m in [spire] + openbaos:
          m.start()
      client.wait_for_unit("spire-server.service", timeout=60)
      fetch_svid()

      with subtest("Health check"):
          token = wait_healthy("openbao1", timeout=180)
          status = seal_status("openbao1")
          show("seal-status", status)
          assert status["type"] == "static" and status["initialized"] and not status["sealed"], status
          servers = raft_servers(token, "openbao1")
          assert len(servers) == 3 and all(s["voter"] for s in servers), servers
          assert leader("openbao1")["leader_address"] != ""
          show("raft node IDs", node_ids(token, "openbao1"))
          for m in openbaos:
              assert_derived(m.name, node_id(token, "openbao1", m.name))
          # Raft state needs a token, which only an SVID can get
          client.fail(curl(url("openbao1", "sys/storage/raft/configuration")))
          # Self-init leaves no recovery keys, and generate-root is not even
          # served: without an SVID that maps to an admin policy there is no
          # way in
          assert status["recovery_seal"] and status["n"] == 0 and status["t"] == 0, status
          generate_root = curl("-o /dev/null -w '%{http_code}' -X PUT", body({}), url("openbao1", "sys/generate-root/attempt"))
          assert client.execute(generate_root)[1] == "405"
          # An admin token can mint recovery keys without any existing share,
          # but they do not open generate-root either
          rotated = json.loads(client.succeed(bao_cmd(token, "openbao1", "sys/rotate/recovery/init", body({"secret_shares": 1, "secret_threshold": 1}))))["data"]
          assert rotated["complete"] and len(rotated["keys"]) == 1, rotated
          assert seal_status("openbao1")["n"] == 1
          assert client.execute(generate_root)[1] == "405"
          # Break-glass while the SPIRE server is down: SVIDs the agent already
          # holds keep working until they expire
          client.succeed("systemctl stop spire-server.service")
          admin_token("openbao2")
          client.succeed("systemctl start spire-server.service")
          client.wait_until_succeeds(f"spire-server healthcheck {server_cli}", timeout=60)

      with subtest("Rolling restart"):
          token = admin_token("openbao2")
          ids = node_ids(token, "openbao2")
          bao(token, "openbao2", "transit/keys/ops", "-X POST")
          first = encrypt(token, "openbao2")
          for m in openbaos:
              other = next(o for o in openbaos if o is not m).name
              if m is openbao3:
                  m.shutdown()
                  check_transit(token, other, [first])
                  m.start()
              else:
                  m.systemctl("stop openbao.service")
                  check_transit(token, other, [first])
                  m.systemctl("start openbao.service")
              token = wait_healthy(other)
              check_transit(token, m.name, [first])
          # openbao3 rebooted
          assert node_ids(token, "openbao1") == ids, ids

      with subtest("Quorum loss and recovery"):
          token = admin_token("openbao1")
          ciphertext = encrypt(token, "openbao1")
          openbao2.systemctl("stop openbao.service")
          openbao3.systemctl("stop openbao.service")
          policy = 'path "quorum/*" { capabilities = ["read"] }'
          client.wait_until_fails(bao_cmd(token, "openbao1", "sys/policies/acl/quorum", body({"policy": policy})), timeout=60)
          assert leader("openbao1").get("leader_address", "") == ""
          # Writes fail, but the lone standby still serves transit from the
          # keys it has cached once it enters read-enabled standby mode, so the
          # API servers keep reading Secrets
          client.wait_until_succeeds(encrypt_cmd(token, "openbao1"), timeout=60)
          client.succeed(decrypt_cmd(token, "openbao1", ciphertext))
          # Logging in writes a token, so a KMS plugin or signer that restarts
          # or whose token expires is locked out until quorum is back
          login = client.execute(
              curl("--cert /tmp/admin/svid.0.pem --key /tmp/admin/svid.0.key", body({"name": "admin"}), url("openbao1", "auth/cert/login")) + " 2>&1"
          )
          assert login[0] != 0 and "active cluster node not found" in login[1], login
          openbao2.systemctl("start openbao.service")
          client.wait_until_succeeds(decrypt_cmd(token, "openbao1", ciphertext), timeout=90)
          openbao3.systemctl("start openbao.service")
          wait_healthy("openbao1")

      with subtest("Replace a member that lost its disk"):
          token = wait_healthy("openbao1")
          ids = node_ids(token, "openbao1")
          [agent_before] = agents(openbao3)
          # A new data disk, same TPM and root file system: the SPIRE agent
          # lost its key and SVID, and the machine ID stays
          openbao3.systemctl("stop openbao.service spire-agent.service")
          openbao3.succeed("rm -rf /var/lib/openbao/* /var/lib/spire/agent")
          openbao3.shutdown()
          openbao3.start()
          client.wait_until_succeeds(unsealed("openbao3"), timeout=120)
          # The agent attests again with the node's TPM under the same agent
          # ID, without an eviction
          [agent_after] = agents(openbao3)
          show("agent before and after", [agent_before, agent_after])
          assert agent_after["id"] == agent_before["id"], (agent_before, agent_after)
          assert agent_after["x509svid_serial_number"] != agent_before["x509svid_serial_number"]
          token = wait_healthy("openbao1")
          servers = raft_servers(token, "openbao1")
          show("servers after rejoin", servers)
          # retry_join rejoins under the same node ID, so the member is replaced
          # in place
          assert sorted(s["node_id"] for s in servers) == ids, servers

      with subtest("Reinstall a member"):
          token = wait_healthy("openbao1")
          old_id = node_id(token, "openbao1", "openbao2")
          machine_id = openbao2.succeed("cat /etc/machine-id").strip()
          # A reinstall loses everything but the TPM. Without /etc/machine-id,
          # systemd generates a new one on the next boot.
          openbao2.systemctl("stop openbao.service spire-agent.service")
          openbao2.succeed("rm -rf /var/lib/openbao/* /var/lib/spire/agent /etc/machine-id")
          openbao2.shutdown()
          openbao2.start()
          client.wait_until_succeeds(unsealed("openbao2"), timeout=120)
          new_machine_id = openbao2.succeed("cat /etc/machine-id").strip()
          show("machine ID before and after", [machine_id, new_machine_id])
          assert re.fullmatch("[0-9a-f]{32}", new_machine_id) and new_machine_id != machine_id, new_machine_id
          token = wait_healthy("openbao1")
          servers = raft_servers(token, "openbao1")
          show("servers after reinstall", servers)
          # The node joins as a new member. It joins at the address of the old
          # one, so autopilot removes the old member as it adds the new one.
          new_id = node_id(token, "openbao1", "openbao2")
          assert_derived("openbao2", new_id)
          assert new_id != old_id, new_id
          assert len(servers) == 3 and old_id not in [s["node_id"] for s in servers], servers

      with subtest("Replace a member with a new machine"):
          token = wait_healthy("openbao1")
          autopilot = bao(token, "openbao1", "sys/storage/raft/autopilot/configuration")["data"]
          show("autopilot configuration", autopilot)
          assert autopilot["cleanup_dead_servers"] and autopilot["min_quorum"] == 3, autopilot

          def voters_are(*names):
              """The voters are the nodes with these host names"""
              state = bao_cmd(token, "openbao1", "sys/storage/raft/autopilot/state")
              hosts = '.data.voters | map(sub("-[0-9a-f]{12}$"; "")) | sort'
              return state + f" | jq -e '.data.healthy and ({hosts}) == {json.dumps(sorted(names))}'"

          # openbao3 is retired and openbao4 replaces it. Once openbao4 is a
          # voter, autopilot removes the dead openbao3.
          openbao3.systemctl("stop openbao.service")
          openbao3.succeed("rm -rf /var/lib/openbao/*")
          openbao3.shutdown()
          openbao4.start()
          client.wait_until_succeeds(unsealed("openbao4"), timeout=180)
          client.wait_until_succeeds(voters_are("openbao1", "openbao2", "openbao4"), timeout=180)
          # Removing a dead openbao4 as well would leave fewer voters than
          # min_quorum, so it stays
          openbao4.shutdown()
          time.sleep(80)
          state = bao(token, "openbao1", "sys/storage/raft/autopilot/state")["data"]
          show("autopilot state with a dead voter", state)
          openbao4_id = node_id(token, "openbao1", "openbao4")
          assert openbao4_id in state["voters"] and state["failure_tolerance"] == 0, state
          # openbao3 comes back on an empty disk, and autopilot removes openbao4
          openbao3.start()
          client.wait_until_succeeds(voters_are("openbao1", "openbao2", "openbao3"), timeout=180)
          wait_healthy("openbao1")

      with subtest("Replace the bootstrap member that lost its disk"):
          token = wait_healthy("openbao2")
          cluster_id = seal_status("openbao2")["cluster_id"]
          ids = node_ids(token, "openbao2")
          secret = encrypt(token, "openbao2", key="kubernetes")
          openbao1.systemctl("stop openbao.service")
          openbao1.succeed("rm -rf /var/lib/openbao/*")
          openbao1.systemctl("start openbao.service")
          client.wait_until_succeeds(unsealed("openbao1"), timeout=120)
          # With empty storage, the bootstrap node finds its peers initialized
          # and joins them through retry_join instead of initializing a new
          # cluster
          rejoined = seal_status("openbao1")
          show("wiped bootstrap node", rejoined)
          assert rejoined["cluster_id"] == cluster_id, rejoined
          openbao1.succeed("journalctl -u openbao -b --no-pager | grep -q 'is initialized, joining its cluster'")
          token = wait_healthy("openbao2")
          assert node_ids(token, "openbao2") == ids, ids
          client.succeed(decrypt_cmd(token, "openbao1", secret, key="kubernetes"))

      with subtest("Raft snapshot backup and restore"):
          token = wait_healthy("openbao2")
          active = leader("openbao2")["leader_address"].split("//")[1].split(".")[0]
          policy = 'path "before/*" { capabilities = ["read"] }'
          bao(token, active, "sys/policies/acl/before", body({"policy": policy}))
          before = encrypt(token, active)
          client.succeed(bao_cmd(token, active, "sys/storage/raft/snapshot", "-o /tmp/raft.snap"))
          client.succeed("test -s /tmp/raft.snap")
          signing = "transit/keys/kubernetes-service-accounts"
          signing_version = bao(token, active, signing)["data"]["latest_version"]
          bao(token, active, f"{signing}/rotate", "-X POST")
          bao(token, active, "transit/keys/ops/rotate", "-X POST")
          after = encrypt(token, active)
          bao(token, active, "sys/policies/acl/after", body({"policy": policy}))
          client.succeed(bao_cmd(token, active, "sys/storage/raft/snapshot-force", "--data-binary @/tmp/raft.snap"))
          token = wait_healthy(active)
          client.succeed(bao_cmd(token, active, "sys/policies/acl/before"))
          client.fail(bao_cmd(token, active, "sys/policies/acl/after"))
          client.succeed(decrypt_cmd(token, active, before))
          # The restore rolled the transit key back to the version before the
          # rotation: whatever was encrypted since is lost
          client.fail(decrypt_cmd(token, active, after))
          # The service account signing key rolls back too: tokens signed with
          # the newer version no longer verify
          assert bao(token, active, signing)["data"]["latest_version"] == signing_version

      with subtest("Full cold start"):
          token = wait_healthy("openbao2")
          ciphertext = encrypt(token, "openbao2")
          if leader("openbao1")["is_self"]:
              bao(token, "openbao1", "sys/step-down", "-X PUT")
              client.wait_until_succeeds(curl(url("openbao1", "sys/leader")) + " | jq -e '.is_self == false and .leader_address != \"\"'", timeout=60)
          # openbao1 rejoined less than a minute ago. Its raft node ID is
          # derived on every start, so a crash before writeback can't change it.
          ids = node_ids(token, "openbao2")
          for m in openbaos:
              m.crash()
          openbao1.start()
          client.wait_until_succeeds(unsealed("openbao1"), timeout=180)
          # The lone node still advertises the crashed active node and answers
          # every request with a redirect to it. openbao-config fails on the
          # empty 307 replies and retries until there is a leader.
          lone = leader("openbao1")
          show("lone node leader", lone)
          assert not lone["is_self"] and lone["leader_address"] != "", lone
          openbao1.wait_until_succeeds("journalctl -u openbao-config -b --no-pager | grep -q 'HTTP 307 from'", timeout=60)
          openbao1.wait_until_succeeds("test $(systemctl show -P NRestarts openbao-config.service) -gt 0", timeout=30)
          openbao1.fail("systemctl is-active openbao-config.service")
          fetch_svid()
          login = client.succeed(
              curl("-o /dev/null -w '%{http_code}' --cert /tmp/admin/svid.0.pem --key /tmp/admin/svid.0.key", body({"name": "admin"}), url("openbao1", "auth/cert/login"))
          )
          assert login == "307", login
          openbao3.start()
          openbao2.start()
          token = wait_healthy("openbao1", timeout=180)
          openbao1.wait_for_unit("openbao-config.service", timeout=60)
          check_transit(token, "openbao1", [ciphertext])
          assert node_ids(token, "openbao1") == ids, ids

      with subtest("Seal key rotation"):
          token = wait_healthy("openbao1")
          ciphertext = encrypt(token, "openbao1")
          for m in openbaos:
              # The openbao unit has restartIfChanged = false: a deployment
              # leaves the old seal configuration running until something
              # restarts OpenBao, e.g. an unrelated reboot weeks later
              out = switch(m, "seal-rotate")[1]
              assert "NOT restarting the following changed units: openbao.service" in out, out
              m.succeed("timeout 60 systemctl restart openbao.service")
              token = wait_healthy(m.name)
          for m in openbaos:
              switch(m, "seal-new")
              m.succeed("timeout 60 systemctl restart openbao.service")
              client.wait_until_succeeds(unsealed(m.name), timeout=60)
          token = wait_healthy("openbao1")
          check_transit(token, "openbao2", [ciphertext])
          # Unsealing with previous_key rewrapped the root key with the new
          # one, so a node that comes up with the old configuration, e.g. a
          # rollback to an older generation, stays sealed
          switch(openbao3)
          openbao3.succeed("timeout 60 systemctl restart openbao.service")
          client.wait_until_succeeds(curl(url("openbao3", "sys/seal-status")) + " | jq -e '.sealed'", timeout=30)
          openbao3.wait_until_succeeds("journalctl -u openbao -b --no-pager | grep -q 'unknown key id for data'", timeout=30)
          switch(openbao3, "seal-new")
          openbao3.succeed("timeout 60 systemctl restart openbao.service")
          token = wait_healthy("openbao1")
          check_transit(token, "openbao3", [ciphertext])
    '';
}
