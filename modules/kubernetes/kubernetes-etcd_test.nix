{ lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };
  members = [
    "etcd1"
    "etcd2"
    "etcd3"
  ];
  etcdctl = "etcdctl --cacert bundle.0.pem --cert svid.0.pem --key svid.0.key";
in
{
  name = "kubernetes-etcd";
  globalTimeout = 300;

  defaults =
    { nodes, ... }:
    {
      imports = [ t.node ];
      networking.extraHosts = t.spireHosts nodes.etcd1;
      # The test driver's shell gets an etcd client SVID instead
      kubernetes.spire.admins = lib.mkForce { };

      kubernetes.etcd = {
        enable = true;
        settings.initial-cluster = lib.concatMapStringsSep "," (
          name: "${name}=https://${name}.${t.domain}:2380"
        ) members;
      };
    };

  nodes = {
    etcd1 = {
      imports = [ t.server ];
      # Same DNS name the API server's SVID carries
      kubernetes.spire.entries.etcd-client = {
        spiffeID = "spiffe://${t.trustDomain}/test/etcd-client";
        selectors = [ "systemd:id:backdoor.service" ];
        dnsNames = [ "kube-apiserver" ];
      };
    };
    etcd2 = { };
    etcd3 = { };
  };

  testScript = ''
    start_all()

    for m in [etcd1, etcd2, etcd3]:
        m.wait_for_unit("etcd.service", timeout=120)

    etcd1.wait_until_succeeds("spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write .", timeout=30)

    with subtest("Members form a cluster over peer mTLS"):
        out = etcd1.succeed("${etcdctl} --endpoints https://etcd1.${t.domain}:2379 member list")
        for name in ${builtins.toJSON members}:
            assert name in out, out

    with subtest("Writes replicate"):
        etcd1.succeed("${etcdctl} --endpoints https://etcd1.${t.domain}:2379 put foo bar")
        out = etcd1.succeed("${etcdctl} --endpoints https://etcd3.${t.domain}:2379 get foo --print-value-only")
        assert out.strip() == "bar", out

    with subtest("Only the API server's DNS name may connect as a client"):
        etcd1.fail("etcdctl --cacert bundle.0.pem --cert /run/etcd-svid/svid.pem --key /run/etcd-svid/svid.key --endpoints https://etcd1.${t.domain}:2379 get foo")

    with subtest("Clients without an SVID are rejected"):
        etcd1.fail("etcdctl --cacert bundle.0.pem --endpoints https://etcd1.${t.domain}:2379 get foo")
  '';
}
