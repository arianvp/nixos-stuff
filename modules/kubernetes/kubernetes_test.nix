{ pkgs, lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };

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
  globalTimeout = 720;

  defaults =
    { config, nodes, ... }:
    {
      imports = [ t.node ];
      networking.extraHosts = t.spireHosts nodes.control;

      kubernetes.serviceCIDR = "fd00:10:96::/112";
      kubernetes.spire.apiServer = "https://control.${t.domain}:6443";
      # Well within the minute between SPIRE preparing and activating a CA
      kubernetes.spire.restartMaxDelaySec = 20;
      kubernetes.clusterDNS = {
        enable = true;
        serviceIP = "fd00:10:96::a";
        # The nodes have no resolver to forward to
        upstreams = [ nodes.control.networking.primaryIPv6Address ];
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
    control =
      { config, ... }:
      {
        imports = [ t.server ];
        # SPIRE prepares the next CA after half of this and switches to it after
        # five sixths, all within the test
        services.spire.server.settings.server = {
          ca_ttl = "3m";
          default_x509_svid_ttl = "1m";
        };
        environment.systemPackages = [ pkgs.openssl ];
        virtualisation.memorySize = 2048;
        virtualisation.cores = 4;

        kubernetes.spire.controlPlane = [ "control" ];
        kubernetes.etcd.enable = true;
        kubernetes.kube-apiserver = {
          enable = true;
          args.advertise-address = config.networking.primaryIPv6Address;
        };
        kubernetes.kube-controller-manager.enable = true;
        kubernetes.kube-scheduler.enable = true;
      };

    worker1 = worker;
    worker2 = worker;
  };

  testScript =
    { nodes, ... }:
    let
      kubeletKubeconfig = nodes.worker1.kubernetes.kubeconfigs.kubelet.file;
      clusterDomain = nodes.control.kubernetes.clusterDomain;
    in
    ''
      import json

      def check_kubelets():
          control.wait_until_succeeds("kubectl wait --for=condition=Ready node/worker1 node/worker2 --timeout=5s", timeout=60)
          control.wait_until_succeeds(f"kubectl logs {pod1}", timeout=60)
          control.wait_until_succeeds(f"kubectl exec {pod1} -- true", timeout=60)

      def check_pods():
          out = control.succeed(f"kubectl exec {pod1} -- wget -qO- http://[{ip2}]/")
          assert out.strip() == pod2, out

      def check_services():
          cluster_ip = control.succeed("kubectl get service web -o jsonpath='{.spec.clusterIP}'").strip()
          control.succeed(f"kubectl exec {pod1} -- wget -qO- http://[{cluster_ip}]/")
          worker2.succeed(f"curl --fail --silent http://[{cluster_ip}]/")

      def check_in_cluster_api():
          sa = "/var/run/secrets/kubernetes.io/serviceaccount"
          out = control.wait_until_succeeds(
              f"kubectl exec {pod1} -- sh -c '"
              f"curl --fail --silent --cacert {sa}/ca.crt -H \"Authorization: Bearer $(cat {sa}/token)\""
              " https://[$KUBERNETES_SERVICE_HOST]:$KUBERNETES_SERVICE_PORT/api'",
              timeout=90,
          )
          assert json.loads(out)["kind"] == "APIVersions", out

      def check_dns():
          control.succeed("kubectl -n kube-system rollout status deployment/coredns --timeout=60s")
          control.wait_until_succeeds(f"kubectl exec {pod1} -- nslookup web.default.svc.${clusterDomain}", timeout=30)
          control.succeed(f"kubectl exec {pod1} -- wget -qO- http://web/")

      start_all()

      control.wait_for_unit("kube-apiserver.service", timeout=120)
      control.wait_for_unit("trust-bundle-svid.service", timeout=60)
      control.succeed("cp /run/trust-bundle-svid/bundle.pem old-ca.pem")
      control.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)

      with subtest("Nodes join"):
          control.wait_until_succeeds("kubectl get node worker1 worker2", timeout=120)
          control.succeed("kubectl wait --for=condition=Ready node/worker1 node/worker2 --timeout=60s")

      with subtest("Nodes are restricted to themselves"):
          user = json.loads(worker1.succeed("kubectl --kubeconfig ${kubeletKubeconfig} auth whoami -o json"))["status"]["userInfo"]
          assert user["username"] == "system:node:worker1", user
          assert "system:nodes" in user["groups"], user
          worker1.fail("kubectl --kubeconfig ${kubeletKubeconfig} label node worker2 foo=bar")

      with subtest("Pods are scheduled on both nodes"):
          control.succeed("kubectl apply -f ${workload}")
          control.succeed("kubectl rollout status deployment/web --timeout=60s")
          pods = json.loads(control.succeed("kubectl get pods -l app=web -o json"))["items"]
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

      with subtest("The cluster keeps working after SPIRE rotates its CA"):
          # Nothing may rely on the old CA once it has expired
          control.wait_until_fails("openssl x509 -in old-ca.pem -noout -checkend 0", timeout=240)
          control.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)
          check_kubelets()
          check_pods()
          check_services()
          check_in_cluster_api()
          check_dns()
    '';
}
