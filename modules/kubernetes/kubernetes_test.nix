# A cluster shaped like production: a SPIRE server, three OpenBao nodes, three
# etcd members, three control planes and two workers, each on their own node.
# Clients reach OpenBao and the API servers by names that resolve to all of
# their nodes.
{ pkgs, lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };
  fqdn = name: "${name}.${t.domain}";

  openbaos = [
    "openbao1"
    "openbao2"
    "openbao3"
  ];
  etcds = [
    "etcd1"
    "etcd2"
    "etcd3"
  ];
  controlPlanes = [
    "control1"
    "control2"
    "control3"
  ];
  clusterCIDR = "fd00:10:244::/56";
  # Each worker gets a /64 of the cluster CIDR, routed to it statically
  workers = {
    worker1 = "fd00:10:244:1::/64";
    worker2 = "fd00:10:244:2::/64";
  };

  testImage = pkgs.dockerTools.buildLayeredImage {
    name = "localhost/k8s-test";
    tag = "latest";
    contents = [
      pkgs.busybox
      pkgs.curl
    ];
    extraCommands = "mkdir -m 1777 tmp";
    config.Cmd = [
      "sh"
      "-c"
      "hostname > /tmp/index.html && exec httpd -f -p 80 -h /tmp"
    ];
  };

  openbao = name: {
    spire.openbao = {
      enable = true;
      spiffeID = "spiffe://${t.trustDomain}/openbao/${name}";
      managers = map (n: "spiffe://${t.trustDomain}/openbao/${n}") openbaos;
      bootstrap = name == lib.head openbaos;
      retryJoin = map (n: "https://${fqdn n}:8200") (lib.remove name openbaos);
      # A real key would be encrypted with systemd-creds
      sealKey.file = pkgs.writeText "openbao-seal-key" "6b2c5f2a2a4e4c1f9d3e7b8a0c1d2e3f4a5b6c7d8e9f00112233445566778899";
      # The test driver's shell
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
  };

  etcd = {
    kubernetes.etcd = {
      enable = true;
      settings.initial-cluster = lib.concatMapStringsSep "," (n: "${n}=https://${fqdn n}:2380") etcds;
    };
  };

  controlPlane =
    { config, ... }:
    {
      virtualisation.memorySize = 2048;
      virtualisation.cores = 4;
      environment.systemPackages = [ pkgs.etcd ];

      kubernetes.kube-apiserver = {
        enable = true;
        args = {
          advertise-address = config.networking.primaryIPv6Address;
          etcd-servers = map (n: "https://${fqdn n}:2379") etcds;
        };
      };
      kubernetes.kube-controller-manager.enable = true;
      kubernetes.kube-scheduler.enable = true;
    };

  worker =
    { config, ... }:
    {
      virtualisation.memorySize = 3072;
      virtualisation.cores = 4;

      systemd.network.config.networkConfig.IPv6Forwarding = "yes";

      kubernetes.kubelet = {
        enable = true;
        args.node-ip = config.networking.primaryIPv6Address;
      };
      kubernetes.kube-proxy = {
        enable = true;
        settings.clusterCIDR = clusterCIDR;
      };
      kubernetes.cni.settings = {
        cniVersion = "1.0.0";
        name = "pods";
        plugins = [
          {
            type = "ptp";
            ipam = {
              type = "host-local";
              ranges = [ [ { subnet = workers.${config.networking.hostName}; } ] ];
              routes = [ { dst = "::/0"; } ];
            };
          }
        ];
      };
      kubernetes.images = [ testImage ];
    };

  workload = pkgs.writeText "workload.json" (
    builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items = [
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata.name = "web";
          spec = {
            replicas = 2;
            selector.matchLabels.app = "web";
            template = {
              metadata.labels.app = "web";
              spec = {
                topologySpreadConstraints = [
                  {
                    maxSkew = 1;
                    topologyKey = "kubernetes.io/hostname";
                    whenUnsatisfiable = "DoNotSchedule";
                    labelSelector.matchLabels.app = "web";
                  }
                ];
                containers = [
                  {
                    name = "web";
                    image = "localhost/k8s-test:latest";
                    imagePullPolicy = "Never";
                    ports = [ { containerPort = 80; } ];
                  }
                ];
              };
            };
          };
        }
        {
          apiVersion = "v1";
          kind = "Service";
          metadata.name = "web";
          spec = {
            selector.app = "web";
            ports = [ { port = 80; } ];
          };
        }
      ];
    }
  );
in
{
  name = "kubernetes";
  globalTimeout = 900;

  defaults =
    { config, nodes, ... }:
    let
      names =
        name: members:
        lib.concatMapStrings (n: "${nodes.${n}.networking.primaryIPv6Address} ${name}\n") members;
    in
    {
      imports = [ t.node ];
      networking.extraHosts =
        t.spireHosts nodes.spire
        + names "api.${t.domain}" controlPlanes
        + names "openbao.${t.domain}" openbaos;
      environment.systemPackages = [
        pkgs.curl
        pkgs.jq
        pkgs.openssl
      ];

      kubernetes.serviceCIDR = "fd00:10:96::/112";
      kubernetes.spire = {
        controlPlane = controlPlanes;
        apiServer = "https://api.${t.domain}:6443";
        apiServerDNSNames = [ "api.${t.domain}" ];
        # Well within the minute between SPIRE preparing and activating a CA
        restartMaxDelaySec = 20;
      };
      kubernetes.clusterDNS = {
        enable = true;
        serviceIP = "fd00:10:96::a";
        # The nodes have no resolver to forward to
        upstreams = [ nodes.spire.networking.primaryIPv6Address ];
      };
      kubernetes.encryption = {
        enable = true;
        openbao = "https://openbao.${t.domain}:8200";
      };

      networking.interfaces.eth1.ipv6.routes =
        lib.mapAttrsToList (
          name: subnet:
          let
            parts = lib.splitString "/" subnet;
          in
          {
            address = lib.head parts;
            prefixLength = lib.toInt (lib.last parts);
            via = nodes.${name}.networking.primaryIPv6Address;
          }
        ) (lib.filterAttrs (name: _: name != config.networking.hostName) workers)
        # There is no default route, without which the host's own connections
        # to service IPs fail before kube-proxy gets to rewrite them
        ++ [
          {
            address = "fd00:10:96::";
            prefixLength = 112;
          }
        ];
    };

  nodes = {
    spire = {
      imports = [ t.server ];
      # SPIRE prepares the next CA after half of this and switches to it after
      # five sixths, all within the test
      services.spire.server.settings.server = {
        ca_ttl = "3m";
        default_x509_svid_ttl = "1m";
      };
    };
    worker1 = worker;
    worker2 = worker;
  }
  // lib.genAttrs openbaos openbao
  // lib.genAttrs etcds (_: etcd)
  // lib.genAttrs controlPlanes (_: controlPlane);

  testScript =
    { nodes, ... }:
    let
      kubeletKubeconfig = nodes.worker1.kubernetes.kubeconfigs.kubelet.file;
      clusterDomain = nodes.control1.kubernetes.clusterDomain;
    in
    ''
      import json

      openbaos = [openbao1, openbao2, openbao3]
      control_planes = [control1, control2, control3]
      etcdctl = (
          "etcdctl --endpoints https://etcd2.${t.domain}:2379 --cacert /run/kube-apiserver-svid/bundle.pem"
          " --cert /run/kube-apiserver-svid/svid.pem --key /run/kube-apiserver-svid/svid.key"
      )

      def check_kubelets():
          control1.wait_until_succeeds("kubectl wait --for=condition=Ready node/worker1 node/worker2 --timeout=5s", timeout=60)
          control1.wait_until_succeeds(f"kubectl logs {pod1}", timeout=60)
          control1.wait_until_succeeds(f"kubectl exec {pod1} -- true", timeout=60)

      def check_pods():
          out = control1.wait_until_succeeds(f"kubectl exec {pod1} -- wget -qO- http://[{ip2}]/", timeout=30)
          assert out.strip() == pod2, out

      def check_services():
          cluster_ip = control1.succeed("kubectl get service web -o jsonpath='{.spec.clusterIP}'").strip()
          control1.wait_until_succeeds(f"kubectl exec {pod1} -- wget -qO- http://[{cluster_ip}]/", timeout=30)
          worker2.wait_until_succeeds(f"curl --fail --silent http://[{cluster_ip}]/", timeout=30)

      def check_in_cluster_api():
          sa = "/var/run/secrets/kubernetes.io/serviceaccount"
          out = control1.wait_until_succeeds(
              f"kubectl exec {pod1} -- sh -c '"
              f"curl --fail --silent --cacert {sa}/ca.crt -H \"Authorization: Bearer $(cat {sa}/token)\""
              " https://[$KUBERNETES_SERVICE_HOST]:$KUBERNETES_SERVICE_PORT/api'",
              timeout=90,
          )
          assert json.loads(out)["kind"] == "APIVersions", out

      def check_dns():
          control1.succeed("kubectl -n kube-system rollout status deployment/coredns --timeout=60s")
          control1.wait_until_succeeds(f"kubectl exec {pod1} -- nslookup web.default.svc.${clusterDomain}", timeout=30)
          control1.succeed(f"kubectl exec {pod1} -- wget -qO- http://web/")

      def etcd_secret(name):
          return f"{etcdctl} get /registry/secrets/default/{name} --print-value-only"

      def read_secret(machine, name):
          """Reads a secret through the API server on the machine"""
          return machine.wait_until_succeeds(
              f"kubectl --server=https://{machine.name}.${t.domain}:6443 get secret {name} -o jsonpath='{{.data.password}}' | base64 -d",
              timeout=60,
          )

      def decrypt_afresh(machine):
          """Restarts the API server, which then has to decrypt with OpenBao again"""
          machine.systemctl("restart kube-kms-openbao.service kube-apiserver.service")
          machine.wait_until_succeeds(f"kubectl --server=https://{machine.name}.${t.domain}:6443 get --raw /readyz", timeout=90)

      def bao(machine, token, path, *args):
          return machine.succeed(
              "curl --silent --show-error --fail-with-body --cacert /run/trust-bundle-svid/bundle.pem"
              f" -H 'X-Vault-Token: {token}' {' '.join(args)} https://{machine.name}.${t.domain}:8200/v1/{path}"
          )

      def unsealed(machine):
          return (
              "curl --silent --fail --cacert /run/trust-bundle-svid/bundle.pem"
              f" https://{machine.name}.${t.domain}:8200/v1/sys/seal-status | jq -e '.sealed == false'"
          )

      def admin_token(machine):
          # The test driver's shell is an admin in OpenBao too
          machine.succeed("mkdir -p admin && spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write admin > /dev/null")
          out = machine.wait_until_succeeds(
              "curl --silent --show-error --fail-with-body --cacert admin/bundle.0.pem"
              " --cert admin/svid.0.pem --key admin/svid.0.key --data '{\"name\": \"admin\"}'"
              f" https://{machine.name}.${t.domain}:8200/v1/auth/cert/login",
              timeout=60,
          )
          return json.loads(out)["auth"]["client_token"]

      start_all()

      for m in control_planes:
          m.wait_for_unit("kube-apiserver.service", timeout=180)
      control1.wait_for_unit("trust-bundle-svid.service", timeout=60)
      control1.succeed("cp /run/trust-bundle-svid/bundle.pem old-ca.pem")
      control1.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)

      with subtest("OpenBao forms a cluster"):
          for m in openbaos:
              m.wait_until_succeeds(unsealed(m), timeout=120)
          token = admin_token(openbao1)
          servers = json.loads(bao(openbao1, token, "sys/storage/raft/configuration"))["data"]["config"]["servers"]
          assert len(servers) == 3, servers

      with subtest("Nodes join"):
          control1.wait_until_succeeds("kubectl get node worker1 worker2", timeout=120)
          control1.succeed("kubectl wait --for=condition=Ready node/worker1 node/worker2 --timeout=60s")

      with subtest("Nodes are restricted to themselves"):
          user = json.loads(worker1.succeed("kubectl --kubeconfig ${kubeletKubeconfig} auth whoami -o json"))["status"]["userInfo"]
          assert user["username"] == "system:node:worker1", user
          assert "system:nodes" in user["groups"], user
          worker1.fail("kubectl --kubeconfig ${kubeletKubeconfig} label node worker2 foo=bar")

      with subtest("Pods are scheduled on both nodes"):
          control1.succeed("kubectl apply -f ${workload}")
          control1.succeed("kubectl rollout status deployment/web --timeout=60s")
          pods = json.loads(control1.succeed("kubectl get pods -l app=web -o json"))["items"]
          by_node = {p["spec"]["nodeName"]: p for p in pods}
          assert set(by_node) == {"worker1", "worker2"}, by_node.keys()
          pod1 = by_node["worker1"]["metadata"]["name"]
          pod2 = by_node["worker2"]["metadata"]["name"]
          ip2 = by_node["worker2"]["status"]["podIP"]
          assert ip2.startswith("fd00:10:244:2:"), ip2

      with subtest("API server reaches the kubelets"):
          check_kubelets()

      with subtest("Pods reach pods on other nodes"):
          check_pods()

      with subtest("Services are reachable"):
          check_services()

      with subtest("Pods reach the API server by the kubernetes Service IP"):
          check_in_cluster_api()

      with subtest("Cluster DNS resolves services"):
          check_dns()

      with subtest("Secrets are encrypted in etcd with OpenBao"):
          control1.succeed("kubectl create secret generic encrypted --from-literal=password=topsecret")
          control1.succeed(f"{etcd_secret('encrypted')} | grep -a -q '^k8s:enc:kms:v2:openbao:'")
          control1.fail(f"{etcd_secret('encrypted')} | grep -a -q topsecret")
          for m in control_planes:
              assert read_secret(m, "encrypted") == "topsecret"

      with subtest("The cluster survives losing an etcd member"):
          etcd1.systemctl("stop etcd.service")
          control1.wait_until_succeeds("kubectl create secret generic without-etcd1 --from-literal=password=etcd", timeout=60)
          assert read_secret(control2, "without-etcd1") == "etcd"
          etcd1.systemctl("start etcd.service")
          etcd1.wait_for_unit("etcd.service", timeout=60)

      with subtest("Secrets stay readable when the active OpenBao node fails"):
          token = admin_token(openbao1)
          leader = json.loads(bao(openbao1, token, "sys/leader"))["leader_address"]
          active = next(m for m in openbaos if f"//{m.name}." in leader)
          active.systemctl("stop openbao.service")
          decrypt_afresh(control2)
          assert read_secret(control2, "encrypted") == "topsecret"
          control2.wait_until_succeeds(
              f"kubectl --server=https://control2.${t.domain}:6443 create secret generic without-{active.name} --from-literal=password=bao",
              timeout=60,
          )
          active.systemctl("start openbao.service")
          active.wait_until_succeeds(unsealed(active), timeout=60)

      with subtest("The API servers follow rotations of the transit key"):
          token = admin_token(openbao2)
          bao(openbao2, token, "transit/keys/kubernetes/rotate", "-X POST")
          control1.wait_until_succeeds(
              "kubectl delete secret rotated --ignore-not-found"
              " && kubectl create secret generic rotated --from-literal=password=rotated"
              f" && {etcd_secret('rotated')} | grep -a -q 'kubernetes:2'",
              timeout=120,
          )
          assert read_secret(control3, "encrypted") == "topsecret"
          assert read_secret(control3, "rotated") == "rotated"

      with subtest("Clients fail over to another API server"):
          control1.systemctl("stop kube-apiserver.service")
          worker1.wait_until_succeeds("kubectl get --raw /readyz", timeout=30)
          control1.wait_until_succeeds("kubectl get --raw /readyz", timeout=30)
          control1.systemctl("start kube-apiserver.service")
          control1.wait_for_unit("kube-apiserver.service", timeout=60)

      with subtest("The cluster keeps working after SPIRE rotates its CA"):
          # Nothing may rely on the old CA once it has expired
          control1.wait_until_fails("openssl x509 -in old-ca.pem -noout -checkend 0", timeout=300)
          control1.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)
          check_kubelets()
          check_pods()
          check_services()
          check_in_cluster_api()
          check_dns()
          # The KMS plugin logs in to OpenBao again, with an SVID from the new CA
          decrypt_afresh(control3)
          assert read_secret(control3, "encrypted") == "topsecret"
    '';
}
