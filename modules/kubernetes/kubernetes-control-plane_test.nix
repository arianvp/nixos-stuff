{ lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };
  transitKey = "kubernetes";

  controlPlane =
    { config, ... }:
    {
      virtualisation.memorySize = 2048;
      virtualisation.cores = 4;

      kubernetes.serviceCIDR = "fd00:10:96::/112";
      kubernetes.spire = {
        controlPlane = [
          "control1"
          "control2"
        ];
        # Resolves to both API servers
        apiServer = "https://api.${t.domain}:6443";
        apiServerDNSNames = [ "api.${t.domain}" ];
        # Well within the minute between SPIRE preparing and activating a CA
        restartMaxDelaySec = 20;
      };
      kubernetes.kube-apiserver = {
        enable = true;
        args.advertise-address = config.networking.primaryIPv6Address;
      };
      kubernetes.kube-jwt-signer.rotationPeriod = "3m";
      kubernetes.encryption = {
        enable = true;
        openbao = "https://control1.${t.domain}:8200";
        key = transitKey;
      };
      kubernetes.kube-controller-manager.enable = true;
      kubernetes.kube-scheduler.enable = true;
    };

  testAddon = {
    apiVersion = "v1";
    kind = "ConfigMap";
    metadata = {
      name = "test-addon";
      namespace = "default";
    };
    data.foo = "bar";
  };
in
{
  name = "kubernetes-control-plane";
  globalTimeout = 600;

  defaults =
    { nodes, pkgs, ... }:
    {
      imports = [
        t.node
        controlPlane
      ];
      networking.extraHosts = t.spireHosts nodes.control1 + ''
        ${nodes.control1.networking.primaryIPv6Address} api.${t.domain}
        ${nodes.control2.networking.primaryIPv6Address} api.${t.domain}
      '';
      environment.systemPackages = [
        pkgs.openssl
        pkgs.curl
        pkgs.jq
      ];
    };

  nodes = {
    control1 =
      { config, pkgs, ... }:
      {
        imports = [ t.server ];
        kubernetes.etcd.enable = true;
        # SPIRE prepares the next CA after half of this and switches to it after
        # five sixths, all within the test
        services.spire.server.settings.server = {
          ca_ttl = "3m";
          default_x509_svid_ttl = "1m";
        };

        kubernetes.addons.manifests = lib.mkIf (!lib.elem "without-test-addon" config.system.nixos.tags) {
          test-addon = testAddon;
        };
        specialisation.without-test-addon.configuration.system.nixos.tags = [ "without-test-addon" ];

        spire.openbao = {
          enable = true;
          spiffeID = "spiffe://${t.trustDomain}/openbao/control1";
          # A real key would be encrypted with systemd-creds
          sealKey.file = pkgs.writeText "openbao-seal-key" "6b2c5f2a2a4e4c1f9d3e7b8a0c1d2e3f4a5b6c7d8e9f00112233445566778899";
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
        kubernetes.spire.entries.openbao = {
          spiffeID = "spiffe://${t.trustDomain}/openbao/control1";
          selectors = [ "systemd:id:openbao-svid.service" ];
          dnsNames = [ "control1.${t.domain}" ];
        };
      };
    control2 = {
      kubernetes.kube-apiserver.args.etcd-servers = [ "https://control1.${t.domain}:2379" ];
    };
  };

  testScript = ''
    import base64
    import json

    def whoami(machine):
        return json.loads(machine.succeed("kubectl auth whoami -o json"))["status"]["userInfo"]

    def kid(token):
        header = token.split(".")[0]
        return json.loads(base64.urlsafe_b64decode(header + "=" * (-len(header) % 4)))["kid"]

    issuer_cmd = "openssl x509 -in /run/kube-apiserver-svid/svid.pem -noout -ext authorityKeyIdentifier | sha256sum"

    def verify_token(verifier, token):
        # The signers exchange keys periodically
        out = verifier.wait_until_succeeds(
            "kubectl auth whoami -o json --kubeconfig=/dev/null"
            f" --server=https://{verifier.name}.${t.domain}:6443"
            " --certificate-authority=/run/trust-bundle-svid/bundle.pem"
            f" --token={token}",
            timeout=90,
        )
        user = json.loads(out)["status"]["userInfo"]
        assert user["username"] == "system:serviceaccount:default:default", user

    def create_token(issuer):
        issuer.wait_until_succeeds("kubectl -n default get serviceaccount default", timeout=60)
        return issuer.wait_until_succeeds(f"kubectl --server=https://{issuer.name}.${t.domain}:6443 create token default", timeout=30).strip()

    def check_tokens():
        for issuer, verifier in [(control1, control2), (control2, control1)]:
            verify_token(verifier, create_token(issuer))


    etcdctl = (
        "etcdctl --endpoints https://control1.${t.domain}:2379 --cacert /run/kube-apiserver-svid/bundle.pem"
        " --cert /run/kube-apiserver-svid/svid.pem --key /run/kube-apiserver-svid/svid.key"
    )

    def etcd_secret(name):
        return f"{etcdctl} get /registry/secrets/default/{name} --print-value-only"

    def read_secret(machine, name):
        return machine.succeed(
            f"kubectl --server=https://{machine.name}.${t.domain}:6443 get secret {name} -o jsonpath='{{.data.password}}' | base64 -d"
        )

    def bao(token, path):
        header = f" -H 'X-Vault-Token: {token}'" if token else ""
        return (
            "curl --silent --show-error --fail-with-body --cacert /run/trust-bundle-svid/bundle.pem"
            f"{header} https://control1.${t.domain}:8200/v1/{path}"
        )

    def admin_token():
        # The test driver's shell is an admin in OpenBao too
        control1.succeed("mkdir -p /root/admin && spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write /root/admin > /dev/null")
        out = control1.succeed(
            "curl --silent --show-error --fail-with-body --cacert /root/admin/bundle.0.pem"
            " --cert /root/admin/svid.0.pem --key /root/admin/svid.0.key --data '{\"name\": \"admin\"}'"
            " https://control1.${t.domain}:8200/v1/auth/cert/login"
        )
        return json.loads(out)["auth"]["client_token"]

    start_all()

    for m in [control1, control2]:
        m.wait_for_unit("kube-apiserver.service", timeout=120)
        m.wait_for_unit("trust-bundle-svid.service", timeout=60)
    control1.succeed("cp /run/trust-bundle-svid/bundle.pem old-ca.pem")
    issuers = {m.name: m.succeed(issuer_cmd) for m in [control1, control2]}

    with subtest("Admins authenticate with their X509-SVID"):
        for m in [control1, control2]:
            m.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)
            user = whoami(m)
            assert user["username"] == "root", user
            assert "system:masters" in user["groups"], user

    with subtest("Other SPIFFE IDs are not admins"):
        control1.fail("systemd-run --wait --pipe --uid=nobody --setenv=KUBECONFIG=$KUBECONFIG kubectl get pods -A")

    with subtest("Addons are applied"):
        control1.wait_for_unit("kube-addons.service", timeout=60)
        control1.succeed("kubectl get clusterrolebinding kube-apiserver:kubelet-api-admin")
        control1.succeed("kubectl -n default get configmap test-addon")

    with subtest("Removed addons are deleted"):
        control1.succeed("/run/current-system/specialisation/without-test-addon/bin/switch-to-configuration test")
        control1.wait_until_fails("kubectl -n default get configmap test-addon", timeout=60)
        control1.succeed("kubectl get clusterrolebinding kube-apiserver:kubelet-api-admin")

    with subtest("Scheduler and controller manager hold their leases"):
        control1.wait_until_succeeds("kubectl -n kube-system get lease kube-scheduler", timeout=60)
        control1.wait_until_succeeds("kubectl -n kube-system get lease kube-controller-manager", timeout=60)

    with subtest("Each API server accepts the service account tokens of the other"):
        check_tokens()
        early_token = create_token(control1)

    with subtest("The API server's certificate is valid for the kubernetes Service IP"):
        control1.succeed(
            "openssl x509 -in /run/kube-apiserver-svid/svid.pem -noout -ext subjectAltName"
            " | grep -i 'IP Address:FD00:10:96:0:0:0:0:1'"
        )

    with subtest("Secrets are encrypted in etcd with OpenBao"):
        control1.wait_for_unit("openbao-config.service", timeout=60)
        control1.wait_until_succeeds("kubectl create secret generic encrypted --from-literal=password=topsecret", timeout=60)
        control1.succeed(f"{etcd_secret('encrypted')} | grep -a -q '^k8s:enc:kms:v2:openbao:'")
        control1.succeed(f"{etcd_secret('encrypted')} | grep -a -q '${transitKey}:1'")
        control1.fail(f"{etcd_secret('encrypted')} | grep -a -q topsecret")
        assert read_secret(control2, "encrypted") == "topsecret"

    with subtest("OpenBao unseals itself"):
        control1.systemctl("restart openbao.service")
        control1.wait_until_succeeds(f"{bao(None, 'sys/seal-status')} | jq -e '.sealed == false'", timeout=60)
        # Without its cached data encryption keys, the API server has to decrypt with OpenBao
        control2.systemctl("restart kube-apiserver.service")
        control2.wait_until_succeeds("kubectl --server=https://control2.${t.domain}:6443 get --raw /readyz", timeout=60)
        assert read_secret(control2, "encrypted") == "topsecret"

    with subtest("The API servers follow rotations of the transit key"):
        token = admin_token()
        control1.succeed(f"{bao(token, 'transit/keys/${transitKey}/rotate')} -X POST")
        control1.wait_until_succeeds(
            "kubectl delete secret rotated --ignore-not-found"
            " && kubectl create secret generic rotated --from-literal=password=rotated"
            f" && {etcd_secret('rotated')} | grep -a -q '${transitKey}:2'",
            timeout=120,
        )
        assert read_secret(control2, "encrypted") == "topsecret"
        assert read_secret(control2, "rotated") == "rotated"
    with subtest("Clients fail over to another API server"):
        control1.systemctl("stop kube-apiserver.service")
        control1.succeed("kubectl get --raw /readyz")
        control1.systemctl("start kube-apiserver.service")
        control1.wait_for_unit("kube-apiserver.service", timeout=60)

    with subtest("Everything keeps working after SPIRE rotates its CA"):
        for m in [control1, control2]:
            m.wait_until_succeeds(f"[ \"$({issuer_cmd})\" != '{issuers[m.name].strip()}' ]", timeout=240)
        # Nothing may rely on the old CA once it has expired
        control1.wait_until_fails("openssl x509 -in old-ca.pem -noout -checkend 0", timeout=120)

        for m in [control1, control2]:
            m.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)
            assert whoami(m)["username"] == "root"
        # Pods get the new CA
        control1.wait_until_succeeds(
            "kubectl -n default get configmap kube-root-ca.crt -o jsonpath='{.data.ca\\.crt}'"
            " | diff - /run/trust-bundle-svid/bundle.pem",
            timeout=60,
        )
        for lease in ["kube-scheduler", "kube-controller-manager"]:
            control1.wait_until_succeeds(
                "renewed=$(kubectl -n kube-system get lease " + lease + " -o jsonpath='{.spec.renewTime}');"
                ' [ $(( $(date +%s) - $(date -d "$renewed" +%s) )) -lt 20 ]',
                timeout=60,
            )
        check_tokens()
        # The KMS plugin logs in to OpenBao again, with an SVID from the new CA
        control2.systemctl("restart kube-kms-openbao.service kube-apiserver.service")
        control2.wait_until_succeeds("kubectl --server=https://control2.${t.domain}:6443 get --raw /readyz", timeout=60)
        assert read_secret(control2, "encrypted") == "topsecret"

    with subtest("Tokens stay valid when the signers rotate their keys"):
        control1.wait_until_succeeds(
            f"[ \"$(kubectl --server=https://control1.${t.domain}:6443 create token default | cut -d. -f1)\" != '{early_token.split('.')[0]}' ]",
            timeout=120,
        )
        late_token = create_token(control1)
        assert kid(late_token) != kid(early_token)
        for verifier in [control1, control2]:
            verify_token(verifier, early_token)
            verify_token(verifier, late_token)
  '';
}
