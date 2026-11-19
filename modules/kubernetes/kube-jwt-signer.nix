# Signs service account tokens with a key in OpenBao's transit secrets engine,
# through the external signer API of kube-apiserver. Set the same options on
# every node: API servers run the signer, the OpenBao node (spire.openbao) gets
# the transit key and the cert auth role the signers log in with.
{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kube-jwt-signer;
  k8s = config.kubernetes;
  svid = config.spire.svids.kube-jwt-signer-openbao;
  # The cert auth role the signers log in with, which the OpenBao node declares
  role = "kubernetes-jwt-signer";
in
{
  imports = [ ../spire/openbao.nix ];

  options.kubernetes.kube-jwt-signer = {
    enable = lib.mkEnableOption ''
      the external service account token signer, which signs with a key in
      OpenBao that every API server shares
    '';

    package = lib.mkPackageOption pkgs "kube-jwt-signer-openbao" { };

    socket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "/run/kube-jwt-signer-openbao/signer.sock";
      description = "Socket the API server signs and verifies tokens through.";
    };

    openbao = lib.mkOption {
      type = lib.types.str;
      description = "URL of OpenBao.";
      example = "https://openbao.example.com:8200";
    };

    transitMount = lib.mkOption {
      type = lib.types.str;
      default = "transit";
      description = "Path of the transit secrets engine.";
    };

    key = lib.mkOption {
      type = lib.types.str;
      default = "${k8s.clusterName}-service-accounts";
      defaultText = lib.literalExpression ''"''${config.kubernetes.clusterName}-service-accounts"'';
      description = "Name of the transit key, created as an ecdsa-p256 key.";
    };

    rotationPeriod = lib.mkOption {
      type = lib.types.strMatching "0|[0-9]+[smh]";
      default = "720h";
      description = ''
        How often OpenBao rotates the signing key; "0" disables rotation.
        OpenBao does not accept less than an hour. A new version signs a minute
        later, once every signer has fetched it, and the versions before it stay
        trusted, so the tokens they signed keep working.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf k8s.kube-apiserver.enable {
        kubernetes.kube-apiserver.args.service-account-signing-endpoint = cfg.socket;

        systemd.services.kube-jwt-signer-openbao = {
          description = "Kubernetes service account token signer";
          # The API server cannot issue tokens without it
          before = [ "kube-apiserver.service" ];
          requiredBy = [ "kube-apiserver.service" ];
          # The signer rereads its SVID on every connection, so it needs no
          # restarts
          requires = [ svid.unit ];
          after = [ svid.unit ];
          serviceConfig = {
            Type = "notify";
            # It keeps starting until OpenBao holds the key and the cert auth
            # role, which openbao-config.service may add much later
            TimeoutStartSec = "infinity";
            ExecStart = lib.escapeShellArgs [
              (lib.getExe cfg.package)
              "-socket"
              cfg.socket
              "-address"
              cfg.openbao
              "-transit-mount"
              cfg.transitMount
              "-key"
              cfg.key
              "-role"
              role
              "-cert-file"
              svid.paths.cert
              "-key-file"
              svid.paths.key
              "-ca-file"
              svid.paths.bundle
            ];
            Restart = "on-failure";
            RestartSec = "5s";
            RuntimeDirectory = "kube-jwt-signer-openbao";
            UMask = "0077";
          };
        };
      })

      (lib.mkIf config.spire.openbao.enable {
        spire.openbao = {
          secretEngines.${cfg.transitMount}.type = "transit";

          policies.${role} = ''
            path "${cfg.transitMount}/sign/${cfg.key}" {
              capabilities = ["update"]
            }
            path "${cfg.transitMount}/keys/${cfg.key}" {
              capabilities = ["read"]
            }
          '';
          certRoles.${role} = {
            allowedURISANs = [ "spiffe://${k8s.spire.trustDomain}/k8s/jwt-signer/*" ];
            policies = [ role ];
          };
          initialize = [
            {
              operation = "update";
              path = "${cfg.transitMount}/keys/${cfg.key}";
              data = {
                type = "ecdsa-p256";
                auto_rotate_period = cfg.rotationPeriod;
              };
            }
          ];
        };
      })
    ]
  );
}
