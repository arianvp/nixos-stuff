# Exercises the procedures of runbooks/control-plane.md: health checks, rolling
# reboots, service account tokens and their signing key, OpenBao and etcd
# outages, worker maintenance and a cold start of the whole cluster after a
# power loss.
#
# One node runs everything the control plane depends on (SPIRE server, etcd and
# OpenBao), so that its outages can be staged one at a time.
{ pkgs, lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };
  fqdn = name: "${name}.${t.domain}";

  controlPlanes = [
    "control1"
    "control2"
  ];
  clusterCIDR = "fd00:10:244::/56";
  workerSubnet = "fd00:10:244:1::/64";

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

  workload = pkgs.writeText "workload.json" (
    builtins.toJSON {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata.name = "web";
      spec = {
        replicas = 1;
        selector.matchLabels.app = "web";
        template = {
          metadata.labels.app = "web";
          spec.containers = [
            {
              name = "web";
              image = "localhost/k8s-test:latest";
              imagePullPolicy = "Never";
              ports = [ { containerPort = 80; } ];
            }
          ];
        };
      };
    }
  );

  controlPlane =
    { config, ... }:
    {
      virtualisation.memorySize = 2048;
      virtualisation.cores = 4;

      kubernetes.kube-apiserver = {
        enable = true;
        args = {
          advertise-address = config.networking.primaryIPv6Address;
          etcd-servers = [ "https://${fqdn "infra"}:2379" ];
        };
      };
      kubernetes.kube-controller-manager.enable = true;
      kubernetes.kube-scheduler.enable = true;
    };
in
{
  name = "ops-control-plane";
  globalTimeout = 1000;

  defaults =
    { nodes, ... }:
    {
      imports = [ t.node ];
      networking.extraHosts =
        t.spireHosts nodes.infra
        + lib.concatMapStrings (
          n: "${nodes.${n}.networking.primaryIPv6Address} api.${t.domain}\n"
        ) controlPlanes;
      environment.systemPackages = [
        pkgs.curl
        pkgs.jq
      ];

      kubernetes.serviceCIDR = "fd00:10:96::/112";
      kubernetes.spire = {
        apiServer = "https://api.${t.domain}:6443";
        apiServerDNSNames = [ "api.${t.domain}" ];
        restartMaxDelaySec = 20;
      };
      kubernetes.kube-jwt-signer = {
        enable = true;
        openbao = t.openbaoURL "infra";
      };
      kubernetes.encryption = {
        enable = true;
        openbao = t.openbaoURL "infra";
      };

      networking.interfaces.eth1.ipv6.routes = [
        {
          address = lib.head (lib.splitString "/" workerSubnet);
          prefixLength = 64;
          via = nodes.worker1.networking.primaryIPv6Address;
        }
        {
          address = "fd00:10:96::";
          prefixLength = 112;
        }
      ];
    };

  nodes = {
    infra = {
      imports = [
        t.server
        t.openbao
      ];
      virtualisation.memorySize = 2048;
      virtualisation.cores = 4;

      kubernetes.etcd.enable = true;
    };
    control1 = controlPlane;
    control2 = controlPlane;
    worker1 =
      { config, ... }:
      {
        virtualisation.memorySize = 3072;
        virtualisation.cores = 4;

        systemd.network.config.networkConfig.IPv6Forwarding = "yes";
        networking.interfaces.eth1.ipv6.routes = lib.mkForce [
          {
            address = "fd00:10:96::";
            prefixLength = 112;
          }
        ];

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
                ranges = [ [ { subnet = workerSubnet; } ] ];
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
      signingKey = nodes.control1.kubernetes.kube-jwt-signer.key;
    in
    ''
      import base64
      import json
      import time

      control_planes = [control1, control2]
      everyone = [infra, control1, control2, worker1]
      control_units = ["kube-jwt-signer-openbao", "kube-kms-openbao", "kube-apiserver", "kube-controller-manager", "kube-scheduler"]
      sa = "/var/run/secrets/kubernetes.io/serviceaccount"
      # Where the operator runs kubectl: a node that stays up during the procedure
      console = worker1

      def measure(what, since):
          print(f"[measure] {what}: {time.monotonic() - since:.1f}s")

      def server(m):
          return f"--server=https://{m.name}.${t.domain}:6443"

      def ready(m):
          return f"kubectl {server(m)} get --raw /readyz"

      def readyz_verbose(m):
          return console.execute(f"kubectl {server(m)} get --raw '/readyz?verbose' 2>&1")[1]

      def dump(m):
          print(m.execute("systemctl list-units --failed --no-legend --plain; systemctl list-jobs --no-legend")[1])
          print(m.execute("journalctl -b --no-pager -o short-monotonic -p warning -n 60")[1])

      def diagnose_on_failure(fn, *machines):
          try:
              return fn()
          except Exception:
              for m in machines:
                  print(f"===== {m.name}")
                  dump(m)
              raise

      def wait_ready(m, timeout):
          return diagnose_on_failure(lambda: m.wait_until_succeeds(ready(m), timeout=timeout), m, infra)

      def pod_api(pod):
          return (
              f"kubectl exec {pod} -- sh -c '"
              f"curl --silent --show-error --max-time 5 -w \"\\n%{{http_code}}\" --cacert {sa}/ca.crt -H \"Authorization: Bearer $(cat {sa}/token)\""
              " https://[$KUBERNETES_SERVICE_HOST]:$KUBERNETES_SERVICE_PORT/api'"
          )

      def in_cluster_api(timeout):
          pod = console.wait_until_succeeds("kubectl get pods -l app=web --field-selector=status.phase=Running -o name | grep .", timeout=timeout).split()[0]
          try:
              console.wait_until_succeeds(f"{pod_api(pod)} | tail -1 | grep -x 200", timeout=timeout)
          except Exception:
              print(console.execute(f"{pod_api(pod)} 2>&1")[1])
              raise

      def read_secret(m, name):
          return m.succeed(f"kubectl {server(m)} get secret {name} -o jsonpath='{{.data.password}}' | base64 -d")

      def write_secret(m, name):
          return f"kubectl {server(m)} create secret generic {name} --from-literal=password={name}"

      def create_token(issuer):
          return issuer.succeed(f"kubectl {server(issuer)} create token default").strip()

      def accepts(verifier, token):
          return (
              "kubectl auth whoami --kubeconfig=/dev/null"
              f" {server(verifier)} --certificate-authority=/run/trust-bundle-svid/bundle.pem --token={token}"
          )

      def kid(token):
          header = token.split(".")[0]
          return json.loads(base64.urlsafe_b64decode(header + "=" * (-len(header) % 4)))["kid"]

      def bao(token, path, method="GET"):
          return (
              f"curl --silent --show-error --fail-with-body -X {method} --cacert /run/trust-bundle-svid/bundle.pem"
              f" -H 'X-Vault-Token: {token}' ${t.openbaoURL "infra"}/v1/{path}"
          )

      def admin_token():
          # The test driver's shell is an admin in OpenBao too
          infra.succeed("mkdir -p /root/admin && spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write /root/admin > /dev/null")
          out = infra.succeed(
              "curl --silent --show-error --fail-with-body --cacert /root/admin/bundle.0.pem"
              " --cert /root/admin/svid.0.pem --key /root/admin/svid.0.key --data '{\"name\": \"admin\"}'"
              " ${t.openbaoURL "infra"}/v1/auth/cert/login"
          )
          return json.loads(out)["auth"]["client_token"]

      def unsealed():
          return (
              "curl --silent --fail --cacert /run/trust-bundle-svid/bundle.pem"
              " ${t.openbaoURL "infra"}/v1/sys/seal-status | jq -e '.sealed == false'"
          )

      def start_probe(m):
          """Records every second whether kubectl reaches an API server by the api. name, and how long it took"""
          m.succeed("rm -f /tmp/probe.log")
          m.execute(
              "nohup sh -c 'while :; do s=$(date +%s.%N);"
              " if kubectl get --raw /readyz --request-timeout=20s > /dev/null 2>&1; then r=ok; else r=fail; fi;"
              " echo \"$s $(date +%s.%N) $r\" >> /tmp/probe.log; sleep 1; done' > /dev/null 2>&1 &"
          )

      def stop_probe(m):
          m.execute("pkill -f 'probe.log'")
          lines = [l.split() for l in m.succeed("cat /tmp/probe.log").splitlines()]
          fails = sum(1 for l in lines if l[2] != "ok")
          slowest = max(float(l[1]) - float(l[0]) for l in lines)
          print(f"[measure] probe on {m.name}: {len(lines)} requests, {fails} failed, slowest {slowest:.1f}s")

      start_all()
      since_boot = time.monotonic()

      for m in control_planes:
          wait_ready(m, 240)
      measure("API servers ready after boot", since_boot)
      control1.wait_until_succeeds("kubectl wait --for=condition=Ready node/worker1 --timeout=5s", timeout=120)
      control1.succeed("kubectl apply -f ${workload}")
      control1.succeed("kubectl rollout status deployment/web --timeout=90s")
      control1.succeed(write_secret(control1, "encrypted"))
      control1.wait_until_succeeds("kubectl get serviceaccount default", timeout=60)

      with subtest("Health check"):
          for m in control_planes:
              out = readyz_verbose(m)
              for check in ["etcd", "kms-providers"]:
                  assert f"[+]{check} ok" in out, out
              console.succeed(f"kubectl {server(m)} get --raw /livez")
              m.succeed(f"systemctl is-active {' '.join(s + '.service' for s in control_units)}")
          user = json.loads(console.succeed("kubectl auth whoami -o json"))["status"]["userInfo"]
          assert user["username"] == "root" and "system:masters" in user["groups"], user
          console.succeed("kubectl get nodes worker1 | grep -w Ready")
          for lease in ["kube-scheduler", "kube-controller-manager"]:
              console.succeed(f"kubectl -n kube-system get lease {lease}")
          in_cluster_api(60)

      with subtest("Rolling reboot of the control plane"):
          for m in control_planes:
              start_probe(worker1)
              m.shutdown()
              since = time.monotonic()
              in_cluster_api(60)
              measure(f"in-pod API access with {m.name} down (two kubectl calls by the api. name)", since)
              since = time.monotonic()
              m.start()
              wait_ready(m, 180)
              measure(f"{m.name} ready after power on", since)
              stop_probe(worker1)
              for u in control_units:
                  m.wait_for_unit(f"{u}.service", timeout=60)
              assert read_secret(m, "encrypted") == "encrypted"
              in_cluster_api(60)
          console.succeed("kubectl get nodes worker1 | grep -w Ready")

      with subtest("Service account tokens and their signing key"):
          # One key in OpenBao signs for every API server
          early_token = create_token(control2)
          control1.succeed(accepts(control1, early_token))
          root = admin_token()
          infra.succeed(bao(root, "transit/keys/${signingKey}/rotate", method="POST"))
          since = time.monotonic()
          # A new version signs only once every signer has fetched it
          late_token = control1.wait_until_succeeds(
              f"t=$(kubectl {server(control1)} create token default) && [ \"$(echo $t | cut -d. -f1)\" != '{early_token.split('.')[0]}' ] && echo $t",
              timeout=150,
          ).strip()
          measure("new signing key version in use after rotation", since)
          assert kid(late_token) != kid(early_token)
          for m in control_planes:
              m.wait_until_succeeds(accepts(m, early_token), timeout=30)
              m.wait_until_succeeds(accepts(m, late_token), timeout=60)

      with subtest("Total OpenBao outage"):
          token = create_token(control1)
          infra.systemctl("stop openbao.service")
          since = time.monotonic()

          # Running API servers serve Secrets from their cached data keys and
          # verify tokens with the public keys their signer holds in memory
          assert read_secret(control1, "encrypted") == "encrypted"
          control1.succeed(write_secret(control1, "during-outage"))
          control1.succeed(accepts(control1, token))
          # Every token is signed by OpenBao, so none can be issued: neither
          # for clients nor for the projected volumes of new pods
          control1.fail(f"kubectl {server(control1)} create token default --request-timeout=20s")
          console.succeed("kubectl run during-outage --image=localhost/k8s-test:latest --image-pull-policy=Never")
          time.sleep(30)
          console.fail("kubectl get pod during-outage -o jsonpath='{.status.phase}' | grep -x Running")
          print(console.succeed("kubectl get events --field-selector involvedObject.name=during-outage -o custom-columns=REASON:.reason,MESSAGE:.message"))

          # An API server that restarts while its signer keeps running comes
          # up but cannot decrypt any Secret
          control2.systemctl("restart kube-apiserver.service")
          control2.wait_for_unit("kube-apiserver.service", timeout=90)
          print(readyz_verbose(control2))
          control2.fail(ready(control2))
          status, out = control2.execute(f"kubectl {server(control2)} get secret encrypted --request-timeout=15s 2>&1")
          assert status != 0 and "corrupt object" in out, out
          control2.succeed(f"kubectl {server(control2)} create configmap during-outage --from-literal=a=b")
          control2.succeed(f"kubectl {server(control2)} get nodes")

          control1.wait_until_fails(ready(control1), timeout=120)
          measure("control1 readyz fails after OpenBao stopped", since)
          print(readyz_verbose(control1))
          control1.wait_until_fails(write_secret(control1, "late-$(date +%s%N)") + " --request-timeout=15s", timeout=240)
          measure("control1 rejects Secret writes after OpenBao stopped", since)
          print(control1.execute(write_secret(control1, "late-$(date +%s%N)") + " --request-timeout=15s 2>&1")[1])
          assert read_secret(control1, "encrypted") == "encrypted"
          in_cluster_api(30)

          # A signer that restarts never becomes ready without OpenBao, and the
          # API server, which Requires= it, never starts: as after a reboot
          control1.succeed("systemctl restart --no-block kube-jwt-signer-openbao.service")
          time.sleep(30)
          control1.succeed("systemctl show -p ActiveState kube-jwt-signer-openbao.service | grep -x ActiveState=activating")
          control1.fail("systemctl is-active kube-apiserver.service")
          console.fail(f"kubectl {server(control1)} get --raw /livez --request-timeout=5s")

          infra.systemctl("start openbao.service")
          since = time.monotonic()
          infra.wait_until_succeeds(unsealed(), timeout=60)
          measure("OpenBao unsealed", since)
          for m in control_planes:
              wait_ready(m, 120)
              measure(f"{m.name} ready after OpenBao started", since)
          control2.wait_until_succeeds(f"kubectl {server(control2)} get secret encrypted", timeout=60)
          control1.wait_until_succeeds(write_secret(control1, "after-outage"), timeout=60)
          control1.wait_until_succeeds(f"kubectl {server(control1)} create token default", timeout=60)
          console.wait_until_succeeds("kubectl get pod during-outage -o jsonpath='{.status.phase}' | grep -x Running", timeout=120)
          measure("Secrets, tokens and new pods work again after OpenBao started", since)
          console.succeed("kubectl delete pod during-outage --wait=false")

      with subtest("etcd outage"):
          infra.systemctl("stop etcd.service")
          since = time.monotonic()
          for m in control_planes:
              console.wait_until_fails(ready(m), timeout=60)
          measure("readyz fails after etcd stopped", since)
          print(readyz_verbose(control1))
          status, _ = console.execute(f"kubectl {server(control1)} get --raw /livez")
          print(f"[measure] livez with etcd down: exit status {status}")
          console.fail("kubectl get nodes --request-timeout=10s")
          ip = worker1.succeed("crictl inspectp $(crictl pods -q --name web --state ready | head -1) | jq -r .status.network.ip").strip()
          time.sleep(20)
          worker1.succeed(f"curl --fail --silent --max-time 5 http://[{ip}]/")
          for m in control_planes:
              print(m.succeed("systemctl show -p NRestarts -p ActiveState kube-controller-manager kube-scheduler kube-apiserver"))

          infra.systemctl("start etcd.service")
          since = time.monotonic()
          for m in control_planes:
              wait_ready(m, 120)
          measure("readyz after etcd started", since)
          console.wait_until_succeeds("kubectl wait --for=condition=Ready node/worker1 --timeout=5s", timeout=60)
          console.wait_until_succeeds(
              "renewed=$(kubectl -n kube-system get lease kube-controller-manager -o jsonpath='{.spec.renewTime}');"
              ' [ $(( $(date +%s) - $(date -d "$renewed" +%s) )) -lt 20 ]',
              timeout=60,
          )
          for m in control_planes:
              for u in control_units:
                  m.wait_for_unit(f"{u}.service", timeout=30)
          worker1.succeed(f"curl --fail --silent --max-time 5 http://[{ip}]/")

      console = control1

      with subtest("Worker maintenance"):
          control1.succeed("kubectl drain worker1 --ignore-daemonsets --delete-emptydir-data --timeout=60s")
          control1.wait_until_succeeds("kubectl get pods -l app=web -o jsonpath='{.items[*].status.phase}' | grep -x Pending", timeout=60)
          since = time.monotonic()
          worker1.shutdown()
          worker1.start()
          control1.wait_until_succeeds("kubectl wait --for=condition=Ready node/worker1 --timeout=5s", timeout=180)
          measure("worker1 Ready after reboot", since)
          control1.succeed("kubectl uncordon worker1")
          control1.succeed("kubectl rollout status deployment/web --timeout=90s")
          in_cluster_api(60)

      with subtest("Cold start in the worst order"):
          for m in everyone:
              m.crash()
          for m in [worker1, control1, control2]:
              m.start()
          time.sleep(30)
          infra.start()
          since = time.monotonic()

          def control_plane_converges():
              for m in control_planes:
                  m.wait_until_succeeds(ready(m), timeout=240)
                  measure(f"{m.name} ready after infra powered on", since)
              control1.wait_until_succeeds("kubectl wait --for=condition=Ready node/worker1 --timeout=5s", timeout=120)
              measure("worker1 Ready after infra powered on", since)
              for m in control_planes:
                  assert read_secret(m, "encrypted") == "encrypted"
          diagnose_on_failure(control_plane_converges, *everyone)

          # CRI-O wipes its storage after an unclean shutdown, and the images
          # are loaded after that
          control1.wait_until_succeeds("kubectl rollout status deployment/web --timeout=5s", timeout=120)
          in_cluster_api(60)
          measure("workload serving after infra powered on", since)
          worker1.succeed("journalctl -b -u crio.service -o cat | grep -q 'Wiping storage directory .* because of unclean shutdown'")
          worker1.succeed("crictl images | grep -q localhost/pause")
          status, out = control1.execute(
              "kubectl get events --field-selector reason=FailedCreatePodSandBox -o jsonpath='{.items[*].message}'"
          )
          assert "localhost/pause" not in out, out

          # A CRI-O restart loads the images again
          before = worker1.succeed("systemctl show -P InvocationID kubernetes-images.service").strip()
          worker1.systemctl("restart crio.service")
          worker1.wait_for_unit("kubernetes-images.service", timeout=60)
          assert worker1.succeed("systemctl show -P InvocationID kubernetes-images.service").strip() != before
          worker1.wait_for_unit("kubelet.service", timeout=60)
          control1.wait_until_succeeds("kubectl rollout status deployment/web --timeout=5s", timeout=60)
    '';
}
