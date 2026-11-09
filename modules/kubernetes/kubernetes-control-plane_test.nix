{ lib, ... }:
let
  t = import ./test-lib.nix { inherit lib; };
  signingKey = "service-accounts";

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
      kubernetes.kube-jwt-signer = {
        openbao = t.openbaoURL "control1";
        key = signingKey;
      };
      kubernetes.kube-controller-manager = {
        enable = true;
        groups.workloads = t.workloadControllers;
      };
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
      { config, ... }:
      {
        imports = [
          t.server
          t.openbao
        ];
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

    def bao(token, path, method="GET"):
        header = f" -H 'X-Vault-Token: {token}'" if token else ""
        return (
            f"curl --silent --show-error --fail-with-body -X {method}"
            " --cacert /run/trust-bundle-svid/bundle.pem"
            f"{header} ${t.openbaoURL "control1"}/v1/{path}"
        )

    def admin_token():
        # The test driver's shell is an admin in OpenBao too
        control1.succeed("mkdir -p /root/admin")
        control1.succeed(
            "spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock"
            " -write /root/admin > /dev/null"
        )
        out = control1.succeed(
            "curl --silent --show-error --fail-with-body --cacert /root/admin/bundle.0.pem"
            " --cert /root/admin/svid.0.pem --key /root/admin/svid.0.key"
            " --data '{\"name\": \"admin\"}'"
            " ${t.openbaoURL "control1"}/v1/auth/cert/login"
        )
        return json.loads(out)["auth"]["client_token"]

    start_all()

    # The signers do not come up, and so the API servers do not, until OpenBao
    # holds the transit key and the cert auth role they log in with
    control1.wait_for_unit("openbao-config.service", timeout=120)
    for m in [control1, control2]:
        m.wait_for_unit("kube-apiserver.service", timeout=180)
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
        control1.wait_until_succeeds("kubectl -n kube-system get lease kube-controller-manager-workloads", timeout=60)

    with subtest("The workload controllers run under an identity of their own"):
        for m in [control1, control2]:
            m.wait_for_unit("kube-controller-manager-workloads.service", timeout=60)
        user = "system:kube-controller-manager-workloads"

        # A ClusterRoleBinding to a role that does not exist is accepted and
        # grants nothing, so every role the group names has to be there
        control1.succeed(
            "kubectl get clusterrole ${
              lib.concatMapStringsSep " " (
                controller: "system:controller:${controller.role}"
              ) t.workloadControllers.controllers
            }"
        )

        # And the bindings have to give the group what its controllers do
        for verb, resource, subresource in [
            ("create", "pods", None),
            ("create", "replicasets.apps", None),
            ("update", "daemonsets.apps", "status"),
            ("update", "replicationcontrollers", "status"),
            ("update", "horizontalpodautoscalers.autoscaling", "status"),
            ("update", "endpoints", None),
            ("create", "endpointslices.discovery.k8s.io", None),
            ("delete", "pods", None),
        ]:
            flags = f" --subresource={subresource}" if subresource else ""
            control1.succeed(f"kubectl auth can-i --as={user} {verb} {resource}{flags}")

        # The controllers left with the controller manager keep their reach
        for verb, resource in [
            ("delete", "namespaces"),
            ("create", "clusterrolebindings.rbac.authorization.k8s.io"),
        ]:
            control1.fail(f"kubectl auth can-i --as={user} {verb} {resource}")

    with subtest("Each API server accepts the service account tokens of the other"):
        check_tokens()
        early_token = create_token(control1)

    with subtest("The API server's certificate is valid for the kubernetes Service IP"):
        control1.succeed(
            "openssl x509 -in /run/kube-apiserver-svid/svid.pem -noout -ext subjectAltName"
            " | grep -i 'IP Address:FD00:10:96:0:0:0:0:1'"
        )

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

    with subtest("Tokens stay valid when OpenBao rotates the signing key"):
        control1.wait_until_succeeds("kubectl get --raw /readyz", timeout=60)
        token = admin_token()
        versions = json.loads(control1.succeed(bao(token, "transit/keys/${signingKey}")))
        assert list(versions["data"]["keys"]) == ["1"], versions["data"]["keys"]
        control1.succeed(bao(token, "transit/keys/${signingKey}/rotate", method="POST"))

        # The new version signs only once every signer has fetched it
        late_token = None
        for _ in range(18):
            candidate = create_token(control1)
            if kid(candidate) != kid(early_token):
                late_token = candidate
                break
            control1.sleep(10)
        assert late_token is not None, f"still signing with {kid(early_token)}"
        # Both versions are trusted, by both API servers
        for verifier in [control1, control2]:
            verify_token(verifier, early_token)
            verify_token(verifier, late_token)
  '';
}
