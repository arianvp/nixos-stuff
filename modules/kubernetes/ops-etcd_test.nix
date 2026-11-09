# Exercises every procedure of runbooks/etcd.md against a three-member etcd
# cluster whose SPIRE server runs on its own node, so members can be wiped and
# rebooted without losing the trust domain.
{ pkgs, lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };
  fqdn = name: "${name}.${t.domain}";
  members = [
    "etcd1"
    "etcd2"
    "etcd3"
  ];
  initialCluster = lib.concatMapStringsSep "," (n: "${n}=https://${fqdn n}:2380") members;
  endpoints = lib.concatMapStringsSep "," (n: "https://${fqdn n}:2379") members;

  member = {
    kubernetes.etcd = {
      enable = true;
      settings.initial-cluster = initialCluster;
    };
    # What an operator deploys for the duration of a procedure
    specialisation.existing.configuration.kubernetes.etcd.settings.initial-cluster-state = "existing";
    specialisation.tiny-quota.configuration.kubernetes.etcd.settings.quota-backend-bytes = 2 * 1024 * 1024;
  };
in
{
  name = "ops-etcd";
  globalTimeout = 600;

  defaults =
    { nodes, ... }:
    {
      imports = [ t.node ];
      networking.extraHosts = t.spireHosts nodes.spire;
      kubernetes.spire.admins = lib.mkForce { };
      environment.systemPackages = [ pkgs.curl ];
    };

  nodes = {
    spire = {
      imports = [ t.server ];
      environment.systemPackages = [
        pkgs.etcd
        pkgs.openssl
      ];
      kubernetes.spire.etcdAdmins.operator = [ "systemd:id:backdoor.service" ];
    };
  }
  // lib.genAttrs members (_: member);

  testScript =
    { nodes, ... }:
    ''
    import json
    import time

    members = [etcd1, etcd2, etcd3]
    ENDPOINTS = "${endpoints}"
    INITIAL_CLUSTER = "${initialCluster}"
    etcdctl = "etcdctl --cacert /root/op/bundle.0.pem --cert /root/op/svid.0.pem --key /root/op/svid.0.key"

    def ep(m):
        return f"https://{m.name}.${t.domain}:2379"

    def ctl(args, endpoints=ENDPOINTS):
        return spire.succeed(f"{etcdctl} --endpoints {endpoints} {args}")

    def wait_healthy(timeout=60):
        spire.wait_until_succeeds(f"{etcdctl} --endpoints {ENDPOINTS} endpoint health --cluster", timeout=timeout)

    def start_writer(unit):
        spire.succeed(
            f"systemd-run --unit {unit} --setenv=PATH=$PATH bash -c '"
            "i=0; while true; do i=$((i+1)); "
            f"if {etcdctl} --endpoints {ENDPOINTS} --command-timeout=3s put /writer/$i $i >/dev/null 2>&1;"
            " then echo ok $i; else echo FAIL $i $(date +%T.%N); fi; sleep 0.2; done'"
        )

    def stop_writer(unit):
        spire.succeed(f"systemctl stop {unit}")
        writes = spire.succeed(f"journalctl -u {unit} -o cat --no-pager")
        oks = writes.count("ok ")
        fails = [l for l in writes.splitlines() if l.startswith("FAIL")]
        print(f"writer: {oks} ok, {len(fails)} failed: {fails}")
        return oks, fails

    # Answers even with an alarm raised, unlike endpoint health
    def wait_serving(timeout=60):
        spire.wait_until_succeeds(f"{etcdctl} --endpoints {ENDPOINTS} endpoint status --cluster", timeout=timeout)

    def revision(m):
        out = ctl("endpoint status -w json", ep(m))
        return json.loads(out)[0]["Status"]["header"]["revision"]

    def agents(m):
        out = spire.succeed("spire-server agent list -socketPath ${nodes.spire.services.spire.server.settings.server.socket_path} -output json")
        selector = {"type": "tpm", "value": f"model:{m.name}"}
        return [a for a in json.loads(out).get("agents", []) if selector in a["selectors"]]

    start_all()
    for m in members:
        m.wait_for_unit("etcd.service", timeout=120)
    spire.succeed("mkdir -p /root/op")
    spire.wait_until_succeeds("spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write /root/op", timeout=30)
    wait_healthy()

    with subtest("health check"):
        print(ctl("endpoint health --cluster -w table"))
        print(ctl("endpoint status --cluster -w table"))
        out = ctl("member list -w table")
        print(out)
        for m in members:
            assert m.name in out, out
        assert ctl("alarm list").strip() == ""
        # A member's own SVID only carries etcd-peer, so members cannot be used
        # as an admin workstation
        etcd1.fail(
            "etcdctl --cacert /run/etcd-svid/bundle.pem --cert /run/etcd-svid/svid.pem"
            f" --key /run/etcd-svid/svid.key --endpoints {ep(etcd1)} --command-timeout=5s endpoint health"
        )
        # etcd auth is off, so the operator identity has full write access
        ctl("put /ops/health ok")

    with subtest("etcd-admin is not a Kubernetes identity"):
        # The API server takes the user from the CN and the groups from O. The
        # operator's SVID has its SPIFFE ID as CN and no O, so it is an
        # ordinary user in no group, never system:masters.
        cert = spire.succeed("openssl x509 -in /root/op/svid.0.pem -noout -subject -ext subjectAltName -nameopt sep_multiline")
        print(cert)
        assert "CN=spiffe://${t.trustDomain}/k8s/etcd-admin/operator" in cert, cert
        assert "O=" not in cert, cert
        assert "DNS:etcd-admin" in cert, cert
        assert "kube-apiserver" not in cert, cert

    with subtest("health and metrics without a client certificate"):
        for m in members:
            out = m.succeed("curl --fail --silent --max-time 5 http://127.0.0.1:2381/health")
            assert json.loads(out)["health"] == "true", out
            out = m.succeed("curl --fail --silent --max-time 5 http://127.0.0.1:2381/metrics")
            assert "etcd_server_has_leader 1" in out, out
        # Only on loopback
        spire.fail(f"curl --silent --max-time 5 http://{etcd1.name}.${t.domain}:2381/health")

    with subtest("rolling restart"):
        start_writer("writer-rolling")
        for m in members:
            started = time.monotonic()
            if m is etcd2:
                m.shutdown()
                m.start()
                m.wait_for_unit("etcd-svid.service", timeout=120)
            else:
                m.systemctl("restart etcd.service")
            m.wait_for_unit("etcd.service", timeout=120)
            wait_healthy()
            print(f"{m.name} back after {time.monotonic() - started:.1f}s")
        oks, fails = stop_writer("writer-rolling")
        assert oks > 20, oks
        # Graceful stops hand over leadership, so no write is lost
        assert fails == [], fails

    with subtest("two members restart at once"):
        # What a trust bundle change does when two random restart delays
        # coincide: if the leader is one of them, its leadership transfer times
        # out and writes fail for several seconds
        start_writer("writer-overlap")
        started = time.monotonic()
        etcd1.succeed("systemctl restart --no-block etcd.service")
        etcd2.succeed("systemctl restart --no-block etcd.service")
        time.sleep(1)
        wait_healthy()
        print(f"healthy again after {time.monotonic() - started:.1f}s")
        time.sleep(2)
        oks, fails = stop_writer("writer-overlap")
        assert oks > 5, oks
        assert len(fails) < oks, fails

    with subtest("quorum loss and recovery"):
        ctl("put /ops/quorum before")
        etcd2.systemctl("stop etcd.service")
        etcd3.systemctl("stop etcd.service")
        spire.fail(f"{etcdctl} --endpoints {ep(etcd1)} --command-timeout=3s put /ops/quorum during")
        spire.fail(f"{etcdctl} --endpoints {ep(etcd1)} --command-timeout=3s get /ops/quorum")
        spire.fail(f"{etcdctl} --endpoints {ep(etcd1)} --command-timeout=3s endpoint health")
        # Serializable reads still answer from the survivor's possibly stale copy
        out = ctl("--command-timeout=3s get /ops/quorum --consistency=s --print-value-only", ep(etcd1))
        assert out.strip() == "before", out
        etcd2.systemctl("start etcd.service")
        spire.wait_until_succeeds(f"{etcdctl} --endpoints {ep(etcd1)},{ep(etcd2)} endpoint health", timeout=60)
        ctl("put /ops/quorum after", f"{ep(etcd1)},{ep(etcd2)}")
        etcd3.systemctl("start etcd.service")
        wait_healthy()
        out = ctl("get /ops/quorum --consistency=s --print-value-only", ep(etcd3))
        assert out.strip() == "after", out

    with subtest("replace a member that lost its disk"):
        [before] = agents(etcd3)
        # Reinstalled on a new disk, same TPM: the SPIRE agent lost its key and SVID
        etcd3.systemctl("stop etcd.service spire-agent.service")
        etcd3.succeed("rm -rf /var/lib/etcd /var/lib/spire/agent")
        etcd3.shutdown()
        etcd3.start()
        # The agent attests again with the node's TPM under the same agent ID,
        # without an eviction
        etcd3.wait_for_unit("etcd-svid.service", timeout=120)
        [after] = agents(etcd3)
        print(f"agent before: {before}\nagent after: {after}")
        assert after["id"] == before["id"], (before, after)
        assert after["x509svid_serial_number"] != before["x509svid_serial_number"], (before, after)
        # With the shipped config (initial-cluster-state "new") the empty member
        # asks its peers whether it was bootstrapped before and refuses to start.
        # That is safe, but systemd restarts it every 5s forever, and nothing
        # tells the operator what to do.
        etcd3.wait_until_succeeds(
            "journalctl -u etcd.service --no-pager -o cat | grep -q 'has already been bootstrapped'", timeout=60
        )
        etcd3.wait_until_succeeds("[ $(systemctl show -P NRestarts etcd.service) -ge 2 ]", timeout=30)
        etcd3.systemctl("stop etcd.service")
        out = ctl("member list", ep(etcd1))
        assert "etcd3" in out, out

        member_id = next(l.split(",")[0] for l in out.splitlines() if ", etcd3," in l)
        ctl(f"member remove {member_id}", ep(etcd1))
        ctl("member add etcd3 --learner --peer-urls https://${fqdn "etcd3"}:2380", ep(etcd1))
        etcd3.succeed("rm -rf /var/lib/etcd")
        etcd3.succeed("/run/current-system/specialisation/existing/bin/switch-to-configuration test")
        etcd3.succeed("systemctl start --no-block etcd.service")
        spire.wait_until_succeeds(
            f"{etcdctl} --endpoints {ep(etcd1)} member promote $({etcdctl} --endpoints {ep(etcd1)} member list"
            " | grep ', etcd3,' | cut -d, -f1)",
            timeout=90,
        )
        etcd3.wait_for_unit("etcd.service", timeout=60)
        wait_healthy()
        out = ctl("get /ops/quorum --consistency=s --print-value-only", ep(etcd3))
        assert out.strip() == "after", out
        assert member_id not in ctl("member list")
        # initial-cluster-state only matters for an empty data dir, so going
        # back to the shipped config is harmless
        etcd3.succeed("/run/booted-system/bin/switch-to-configuration test")
        etcd3.wait_for_unit("etcd.service", timeout=60)
        wait_healthy()

    with subtest("snapshot backup and full restore"):
        ctl("put /ops/dr before-snapshot")
        spire.succeed(f"{etcdctl} --endpoints {ep(etcd1)} snapshot save /tmp/shared/etcd.db")
        print(spire.succeed("etcdutl snapshot status /tmp/shared/etcd.db -w table"))
        ctl("put /ops/dr-lost after-snapshot")
        old_rev = revision(etcd1)
        for m in members:
            m.systemctl("stop etcd.service")
        for m in members:
            m.succeed(
                "rm -rf /var/lib/etcd && etcdutl snapshot restore /tmp/shared/etcd.db"
                f" --name {m.name} --initial-cluster {INITIAL_CLUSTER}"
                f" --initial-advertise-peer-urls https://{m.name}.${t.domain}:2380"
                " --data-dir /var/lib/etcd --bump-revision 1000000000 --mark-compacted"
            )
        # A member reports ready only once a quorum is up
        for m in members:
            m.succeed("systemctl start --no-block etcd.service")
        for m in members:
            m.wait_for_unit("etcd.service", timeout=60)
        wait_healthy()
        out = ctl("get /ops/dr --print-value-only")
        assert out.strip() == "before-snapshot", out
        assert ctl("get /ops/dr-lost --print-value-only").strip() == ""
        new_rev = revision(etcd1)
        assert new_rev > old_rev + 1000000000 - 100, (old_rev, new_rev)

    with subtest("compaction, defrag and space quota"):
        for m in members:
            ctl("defrag", ep(m))
            wait_healthy()
        assert ctl("alarm list").strip() == ""

        etcd1.succeed("/run/current-system/specialisation/tiny-quota/bin/switch-to-configuration test")
        etcd1.wait_for_unit("etcd.service", timeout=60)
        wait_healthy()
        for i in range(40):
            rc, _ = spire.execute(f"head -c 196608 /dev/urandom | base64 -w0 | {etcdctl} --endpoints {ep(etcd1)} put /big/{i}")
            if rc != 0:
                break
        else:
            raise Exception("the space quota was never hit")
        print(ctl("endpoint status --cluster -w table"))
        assert "NOSPACE" in ctl("alarm list")
        # One member over its quota makes the whole cluster refuse writes, and
        # every member reports unhealthy until the alarm is disarmed
        out = spire.fail(f"{etcdctl} --endpoints {ep(etcd2)} put /ops/nospace x 2>&1")
        assert "database space exceeded" in out, out
        out = spire.fail(f"{etcdctl} --endpoints {ENDPOINTS} endpoint health --cluster 2>&1")
        assert out.count("Active Alarm(s): NOSPACE") == 3, out

        etcd1.succeed("/run/booted-system/bin/switch-to-configuration test")
        etcd1.wait_for_unit("etcd.service", timeout=60)
        wait_serving()
        ctl("del --prefix /big")
        ctl(f"compaction {revision(etcd1)}")
        for m in members:
            ctl("defrag", ep(m))
            wait_serving()
        print(ctl("endpoint status --cluster -w table"))
        # The alarm survives the restart and the compaction until disarmed
        assert "NOSPACE" in ctl("alarm list")
        ctl("alarm disarm")
        assert ctl("alarm list").strip() == ""
        ctl("put /ops/nospace recovered")
        wait_healthy()
  '';
}
