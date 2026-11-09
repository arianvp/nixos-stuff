# Maintenance of the SPIRE server and agents, and what it does to a cluster
# bootstrapped from SPIRE (runbooks/spire.md). Every agent attests with its
# TPM. control1's agent bootstraps like production (the bundle from the
# server's web PKI bundle endpoint, rebootstrap), worker1's is the test-lib
# default, and the spire node's own agent keeps its keys in memory. The spire
# node also runs OpenBao, which the API server signs service account tokens with.
{ pkgs, lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };

  testImage = pkgs.dockerTools.buildLayeredImage {
    name = "localhost/k8s-test";
    tag = "latest";
    contents = [ pkgs.busybox ];
    config.Cmd = [
      "sleep"
      "infinity"
    ];
  };

  pod = pkgs.writeText "pod.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "Pod";
      metadata.name = "web";
      spec.containers = [
        {
          name = "web";
          image = "localhost/k8s-test:latest";
          imagePullPolicy = "Never";
        }
      ];
    }
  );

  # A web PKI certificate for the server's bundle endpoint, which production
  # gets from ACME
  bundleEndpointCert = pkgs.runCommand "spire-bundle-endpoint-cert" { nativeBuildInputs = [ pkgs.openssl ]; } ''
    mkdir $out
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 3650 \
      -subj /CN=web-ca -keyout ca.key -out $out/ca.crt
    openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
      -subj /CN=spire.${t.domain} -keyout $out/server.key -out server.csr
    printf 'subjectAltName=DNS:spire.${t.domain}\nextendedKeyUsage=serverAuth\n' > ext
    openssl x509 -req -in server.csr -CA $out/ca.crt -CAkey ca.key -days 3650 -extfile ext -out $out/server.crt
    chmod 0644 $out/server.key
  '';
in
{
  name = "ops-spire";
  globalTimeout = 900;

  defaults =
    { nodes, ... }:
    {
      imports = [ t.node ];
      networking.extraHosts = t.spireHosts nodes.spire;
      environment.systemPackages = [
        pkgs.jq
        pkgs.openssl
        pkgs.curl
      ];
      kubernetes.serviceCIDR = "fd00:10:96::/112";
      kubernetes.spire = {
        controlPlane = [ "control1" ];
        apiServer = "https://control1.${t.domain}:6443";
        restartMaxDelaySec = 10;
      };
      # The API server signs service account tokens with a key in OpenBao,
      # which the OpenBao node creates
      kubernetes.kube-jwt-signer = {
        enable = true;
        openbao = t.openbaoURL "spire";
      };
    };

  nodes = {
    spire = {
      imports = [
        t.server
        t.openbao
      ];
      virtualisation.memorySize = 2048;
      environment.systemPackages = [ pkgs.sqlite ];
      networking.firewall.allowedTCPPorts = [ 8443 ];
      services.spire.server.settings = {
        # The CA does not rotate during the test, so restarts are caused by
        # the procedures alone
        server = {
          ca_ttl = "1h";
          default_x509_svid_ttl = "1m";
        };
        server.federation.bundle_endpoint = {
          address = "::";
          port = 8443;
          profile.https_web.serving_cert_file = {
            cert_file_path = "${bundleEndpointCert}/server.crt";
            key_file_path = "${bundleEndpointCert}/server.key";
            # SPIRE fails to parse the config without it
            file_sync_interval = "1h";
          };
        };
      };
      services.spire.agent.settings.plugins.KeyManager = lib.mkForce {
        memory.plugin_data = { };
      };
    };

    control1 =
      { config, ... }:
      {
        virtualisation.memorySize = 2048;
        virtualisation.cores = 4;
        security.pki.certificateFiles = [ "${bundleEndpointCert}/ca.crt" ];
        services.spire.agent.settings.agent = {
          # SPIRE refuses to rebootstrap with insecure_bootstrap
          insecure_bootstrap = lib.mkForce false;
          trust_bundle_url = "https://spire.${t.domain}:8443";
          trust_bundle_format = "spiffe";
          rebootstrap_mode = "auto";
          rebootstrap_delay = "30s";
        };
        kubernetes.etcd.enable = true;
        kubernetes.kube-apiserver = {
          enable = true;
          args.advertise-address = config.networking.primaryIPv6Address;
        };
        kubernetes.kube-controller-manager.enable = true;
        kubernetes.kube-scheduler.enable = true;
      };

    worker1 =
      { config, ... }:
      {
        virtualisation.memorySize = 2048;
        virtualisation.cores = 4;
        kubernetes.kubelet = {
          enable = true;
          args.node-ip = config.networking.primaryIPv6Address;
        };
        kubernetes.kube-proxy = {
          enable = true;
          settings.clusterCIDR = "fd00:10:244::/56";
        };
        kubernetes.cni.settings = {
          cniVersion = "1.0.0";
          name = "pods";
          plugins = [
            {
              type = "ptp";
              ipam = {
                type = "host-local";
                ranges = [ [ { subnet = "fd00:10:244:1::/64"; } ] ];
                routes = [ { dst = "::/0"; } ];
              };
            }
          ];
        };
        kubernetes.images = [ testImage ];
      };
  };

  testScript =
    { nodes, ... }:
    let
      kubeletKubeconfig = nodes.worker1.kubernetes.kubeconfigs.kubelet.file;
      serverSocket = nodes.spire.services.spire.server.settings.server.socket_path;
      agentSocket = nodes.control1.services.spire.agent.settings.agent.socket_path;
      entryCount = lib.length (lib.attrNames nodes.spire.kubernetes.spire.server.entries);
    in
    ''
      import json
      import time

      server_cli = "-socketPath ${serverSocket}"
      openbao = "${t.openbaoURL "spire"}"
      agent_health = "spire-agent healthcheck -socketPath ${agentSocket}"
      etcdctl = (
          "etcdctl --endpoints https://control1.${t.domain}:2379 --cacert /run/kube-apiserver-svid/bundle.pem"
          " --cert /run/kube-apiserver-svid/svid.pem --key /run/kube-apiserver-svid/svid.key"
      )
      # The server runs with DynamicUser, so its StateDirectory lives here
      state_dir = "/var/lib/private/spire/server"
      consumers = {
          control1: ["etcd.service", "kube-apiserver.service", "kube-jwt-signer-openbao.service", "kube-controller-manager.service", "kube-scheduler.service"],
          worker1: ["kubelet.service", "kube-proxy.service"],
          spire: ["openbao.service"],
      }
      agents = [spire, control1, worker1]
      # They exit when they lose their leader lease, which they do whenever the
      # API server is unreachable for long
      leader_elected = {"control1/kube-controller-manager.service", "control1/kube-scheduler.service"}

      def invocations():
          return {
              f"{m.name}/{u}": m.succeed(f"systemctl show -P InvocationID {u}").strip()
              for m, units in consumers.items()
              for u in units
          }

      def restarted_since(before):
          after = invocations()
          return {k for k in before if before[k] != after[k]}

      def lease_fresh(node):
          return (
              f"renewed=$(kubectl -n kube-node-lease get lease {node} -o jsonpath='{{.spec.renewTime}}');"
              ' [ $(( $(date +%s) - $(date -d "$renewed" +%s) )) -lt 20 ]'
          )

      def check_cluster(timeout=60):
          control1.wait_until_succeeds("kubectl get --raw /readyz", timeout=timeout)
          control1.wait_until_succeeds(f"{etcdctl} endpoint health", timeout=timeout)
          control1.wait_until_succeeds(lease_fresh("worker1"), timeout=timeout)
          control1.wait_until_succeeds("kubectl exec web -- true", timeout=timeout)
          worker1.wait_until_succeeds("kubectl --kubeconfig ${kubeletKubeconfig} get --raw /readyz", timeout=timeout)
          control1.wait_until_succeeds("kubectl create token default", timeout=timeout)
          control1.wait_until_succeeds(f"curl --fail --silent --cacert /run/trust-bundle-svid/bundle.pem {openbao}/v1/sys/health", timeout=timeout)

      def bundle():
          return spire.succeed(f"spire-server bundle show {server_cli}")

      def agent_list():
          return json.loads(spire.succeed(f"spire-server agent list {server_cli} -output json")).get("agents") or []

      def agent_ids(m):
          """The agent IDs the server knows for the TPM of node m"""
          return [
              f"spiffe://{a['id']['trust_domain']}{a['id']['path']}"
              for a in agent_list()
              if {"type": "tpm", "value": f"model:{m.name}"} in a.get("selectors", [])
          ]

      def agent_logged(m, text, since):
          return f"journalctl -u spire-agent.service --since @{since} -o cat | grep -q '{text}'"

      def now():
          return int(spire.succeed("date +%s"))

      def agent_result(m):
          return m.succeed("systemctl show -P Result spire-agent.service").strip()

      def agent_restarts(m):
          return int(m.succeed("systemctl show -P NRestarts spire-agent.service"))

      def time_to_recovery(machines, timeout, cmd):
          """Seconds until cmd first succeeds on each machine"""
          start = time.monotonic()
          times = {}
          while len(times) < len(machines) and time.monotonic() - start < timeout:
              for m in machines:
                  if m.name not in times and m.execute(cmd)[0] == 0:
                      times[m.name] = int(time.monotonic() - start)
                      print(f"t={times[m.name]}s: {m.name} recovered", flush=True)
              time.sleep(2)
          return times

      def wipe_agent(m):
          """Make an agent forget its bundle and SVID, and bootstrap afresh"""
          m.succeed(
              "systemctl stop spire-agent.service && rm -rf /var/lib/spire/agent/*"
              " && systemctl reset-failed spire-agent.service && systemctl start spire-agent.service"
          )

      def stop_server():
          spire.systemctl("stop spire-server.service")
          return now()

      def start_server():
          spire.systemctl("start spire-server.service")
          spire.wait_until_succeeds(f"spire-server healthcheck {server_cli}", timeout=60)

      probes = {
          "admin kubectl (SVID fetched from the agent)": (control1, "timeout 5 kubectl get --raw /readyz"),
          "control1 agent": (control1, f"timeout 5 {agent_health}"),
          "etcd via the API server's SVID": (control1, f"timeout 5 {etcdctl} endpoint health"),
          "kubelet's SVID -> API server": (worker1, "timeout 5 kubectl --kubeconfig ${kubeletKubeconfig} get --raw /readyz"),
          "kube-apiserver SVID file unexpired": (control1, "openssl x509 -checkend 0 -noout -in /run/kube-apiserver-svid/svid.pem"),
          "token issuance (signer -> OpenBao)": (control1, "timeout 10 kubectl create token default"),
          "OpenBao SVID file unexpired": (spire, "openssl x509 -checkend 0 -noout -in /run/openbao-svid/svid.pem"),
      }

      def time_to_failure(timeout):
          """Seconds until each probe first fails"""
          failed = {}
          start = time.monotonic()
          while len(failed) < len(probes) and time.monotonic() - start < timeout:
              for name, (m, cmd) in probes.items():
                  if name not in failed and m.execute(cmd)[0] != 0:
                      failed[name] = int(time.monotonic() - start)
                      print(f"t={failed[name]}s: {name} fails", flush=True)
              time.sleep(2)
          return failed

      start_all()

      for m in agents:
          m.wait_until_succeeds(agent_health, timeout=120)
      control1.wait_for_unit("kube-apiserver.service", timeout=120)
      control1.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)
      control1.wait_until_succeeds("kubectl get node worker1", timeout=120)
      control1.succeed("kubectl wait --for=condition=Ready node/worker1 --timeout=60s")
      control1.wait_until_succeeds("kubectl apply -f ${pod}", timeout=60)
      control1.succeed("kubectl wait --for=condition=Ready pod/web --timeout=60s")
      check_cluster()

      with subtest("Health check"):
          spire.succeed(f"spire-server healthcheck {server_cli}")
          spire.succeed(f"spire-server localauthority x509 show {server_cli} | grep -A1 'Active X.509 authority' | grep 'Authority ID'")
          spire.succeed(f"spire-server bundle show {server_cli} | openssl x509 -noout -checkend 0")
          spire.wait_until_succeeds(
              f"[ $(spire-server entry show {server_cli} -output json | jq '.entries | length') = ${toString entryCount} ]",
              timeout=30,
          )
          assert len(agent_list()) == len(agents), agent_list()
          for m in agents:
              ids = agent_ids(m)
              assert len(ids) == 1 and ids[0].startswith("spiffe://${t.trustDomain}/spire/agent/tpm/"), ids
          assert all(a["can_reattest"] for a in agent_list()), agent_list()
          for m in agents:
              m.succeed(agent_health)
          for m in consumers:
              m.succeed("systemctl is-active $(systemctl list-units --plain --no-legend '*-svid.service' | cut -d' ' -f1)")
              # Every SVID on disk is valid and lives no longer than its TTL
              m.succeed("for f in /run/*-svid/svid.pem; do openssl x509 -in $f -noout -checkend 0 && ! openssl x509 -in $f -noout -checkend 61; done")
          # Copying the database alone loses what is still in the write-ahead log
          assert spire.succeed(f"sqlite3 {state_dir}/datastore.sqlite3 'pragma journal_mode'").strip() == "wal"
          spire.succeed(
              "mkdir -p /root/stale"
              f" && sqlite3 {state_dir}/datastore.sqlite3 '.backup /root/stale/datastore.sqlite3'"
              f" && cp {state_dir}/keys.json /root/stale/"
          )

      with subtest("Agent restart"):
          before = invocations()
          ids = {m.name: agent_ids(m) for m in agents}
          since = now()
          for m in [control1, worker1]:
              m.systemctl("restart spire-agent.service")
          for m in [control1, worker1]:
              m.wait_until_succeeds(agent_health, timeout=30)
              m.succeed(agent_logged(m, "SVID loaded", since))
              m.fail(agent_logged(m, "Starting node attestation", since))
          check_cluster()
          assert restarted_since(before) == set(), restarted_since(before)
          assert {m.name: agent_ids(m) for m in agents} == ids

      with subtest("Agent restart with keys in memory"):
          # The agent loses its key and attests again with its TPM, under the
          # same agent ID
          before = invocations()
          ids = agent_ids(spire)
          since = now()
          spire.systemctl("restart spire-agent.service")
          spire.wait_until_succeeds(agent_logged(spire, "Node attestation was successful", since), timeout=30)
          spire.wait_until_succeeds(agent_health, timeout=30)
          assert agent_result(spire) == "success"
          assert agent_ids(spire) == ids, agent_ids(spire)
          check_cluster()
          assert restarted_since(before) == set(), restarted_since(before)

      with subtest("SPIRE server restart"):
          before = invocations()
          old_bundle = bundle()
          spire.systemctl("restart spire-server.service")
          spire.wait_until_succeeds(f"spire-server healthcheck {server_cli}", timeout=60)
          assert bundle() == old_bundle
          # Past the next renewal of every SVID
          time.sleep(35)
          check_cluster()
          for m in agents:
              m.succeed(agent_health)
          assert restarted_since(before) == set(), restarted_since(before)

      with subtest("SPIRE server backup and restore"):
          before = invocations()
          old_bundle = bundle()
          spire.succeed(
              "rm -rf /root/backup && mkdir /root/backup"
              f" && sqlite3 {state_dir}/datastore.sqlite3 '.backup /root/backup/datastore.sqlite3'"
              f" && cp {state_dir}/keys.json /root/backup/"
          )
          stop_server()
          spire.succeed(f"rm -rf {state_dir}/*")
          spire.succeed(f"cp /root/backup/* {state_dir}/ && chown -R --reference={state_dir} {state_dir} && chmod 0600 {state_dir}/*")
          start_server()
          assert bundle() == old_bundle
          time.sleep(35)
          check_cluster()
          for m in agents:
              m.succeed(agent_health)
          assert restarted_since(before) == set(), restarted_since(before)

      with subtest("SPIRE server restore from a backup older than an agent SVID"):
          # The restored datastore expects agent SVIDs that the agents have
          # since replaced, so it denies them, and they attest again
          before = invocations()
          restarts = {m.name: agent_restarts(m) for m in agents}
          since = stop_server()
          spire.succeed(f"rm -rf {state_dir}/*")
          spire.succeed(f"cp /root/stale/* {state_dir}/ && chown -R --reference={state_dir} {state_dir} && chmod 0600 {state_dir}/*")
          start_server()
          # Within the next rotation of every agent SVID
          for m in agents:
              m.wait_until_succeeds(agent_logged(m, "Successfully reattested node", since), timeout=60)
              m.succeed(agent_health)
          assert {m.name: agent_restarts(m) for m in agents} == restarts
          check_cluster()
          assert restarted_since(before) == set(), restarted_since(before)

      with subtest("SPIRE server outage longer than the SVID lifetime"):
          before = invocations()
          restarts = {m.name: agent_restarts(m) for m in agents}
          since = stop_server()
          failed = time_to_failure(90)
          assert set(failed) == set(probes), failed
          # An agent exits once when its SVID expires, then keeps trying to
          # attest without exiting, so it stays clear of systemd's start limit
          time.sleep(30)
          for m in agents:
              m.succeed(agent_logged(m, "current SVID has already expired and reattest agent failed", since))
              m.succeed("systemctl is-active spire-agent.service")
              assert agent_restarts(m) > restarts[m.name]
              print(f"{m.name}: spire-agent restarted {agent_restarts(m) - restarts[m.name]} times during the outage", flush=True)
          start = time.monotonic()
          start_server()
          recovered = time_to_recovery(agents, 60, f"timeout 5 {agent_health}")
          assert len(recovered) == len(agents), recovered
          check_cluster(timeout=90)
          print(f"the cluster recovered {int(time.monotonic() - start)}s after the server started", flush=True)
          assert restarted_since(before) <= leader_elected, restarted_since(before)

      with subtest("SPIRE server lost without backup"):
          before = invocations()
          old_bundle = bundle()
          since = stop_server()
          spire.succeed(f"rm -rf {state_dir}/*")
          start_server()
          start = time.monotonic()
          new_bundle = bundle()
          assert new_bundle != old_bundle
          # The controller manager registers the entries of all nodes again
          spire.wait_until_succeeds(
              f"[ $(spire-server entry show {server_cli} -output json | jq '.entries | length') = ${toString entryCount} ]",
              timeout=60,
          )
          for m in agents:
              m.succeed(f"cat > /tmp/new-bundle.pem <<'EOF'\n{new_bundle}\nEOF")
          on_new_ca = "openssl verify -CAfile /tmp/new-bundle.pem $(ls /run/*-svid/svid.pem | head -1)"

          # control1 fetches the new bundle from the bundle endpoint and
          # attests again
          control1.wait_until_succeeds(agent_logged(control1, "agree, rebootstrapping", since), timeout=90)
          control1.wait_until_succeeds(on_new_ca, timeout=60)
          print(f"control1 rebootstrapped {int(time.monotonic() - start)}s after the new server started", flush=True)

          # Agents that bootstrap insecurely (the test-lib default) cannot
          # rebootstrap, so they refuse the new server until they are wiped
          for m in [spire, worker1]:
              m.succeed(agent_logged(m, "signed by unknown authority", since))
              m.fail(on_new_ca)
          start = time.monotonic()
          for m in [spire, worker1]:
              wipe_agent(m)
          for m in [spire, worker1]:
              m.wait_until_succeeds(agent_health, timeout=60)
          # Consumers restart for the CA they have not seen
          check_cluster(timeout=150)
          print(f"the cluster recovered {int(time.monotonic() - start)}s after the agents were wiped", flush=True)
          assert restarted_since(before) >= {"control1/etcd.service", "control1/kube-apiserver.service", "worker1/kubelet.service"}, restarted_since(before)

          # BAD: OpenBao's cert auth roles still trust only the old CA, and
          # openbao-config has to log in with cert auth to replace it, so it
          # never can. Tokens are only issued because the signer still holds
          # the OpenBao token it got before. Once it has to log in again, the
          # API server, which requires it, does not come back.
          spire.wait_until_succeeds("journalctl -u openbao-config.service --since @" + str(since) + " | grep -q 'permission denied'", timeout=60)
          spire.fail("systemctl is-active openbao-config.service")
          control1.succeed("systemctl restart --no-block kube-jwt-signer-openbao.service")
          control1.wait_until_fails("kubectl get --raw /readyz", timeout=30)
          time.sleep(30)
          control1.fail("timeout 5 kubectl get --raw /readyz")
          assert control1.succeed("systemctl show -P ActiveState kube-jwt-signer-openbao.service").strip() == "activating"
          control1.fail("systemctl is-active kube-apiserver.service")

      with subtest("Registration entries come from the configuration of the SPIRE server"):
          # Adding a node, or any workload on one, means deploying the SPIRE server
          spire.succeed("test -e /etc/spire/server/manifests/worker1-kubelet.yaml")
          assert int(spire.succeed("ls /etc/spire/server/manifests | wc -l")) == ${toString entryCount}
    '';
}
