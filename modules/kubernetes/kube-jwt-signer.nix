{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.kube-jwt-signer;
in
{
  options.kubernetes.kube-jwt-signer = {
    enable = lib.mkEnableOption ''
      the external service account token signer, which keeps a signing key
      per API server and trusts the keys of its peers
    '';

    package = lib.mkPackageOption pkgs "kube-jwt-signer" { };

    socket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "/run/kube-jwt-signer/signer.sock";
      description = "Socket the API server signs and verifies tokens through.";
    };

    rotationPeriod = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = ''
        How long a signing key signs before the next takes over, as a Go
        duration; "0" disables rotation. Superseded keys stay trusted until the
        tokens they signed have expired.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 10260;
      description = "Port on which peers fetch this signer's public keys.";
    };

    peers = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            spiffeID = lib.mkOption {
              type = lib.types.str;
              description = "SPIFFE ID the peer must authenticate as.";
            };
            url = lib.mkOption {
              type = lib.types.str;
              description = "URL of the peer.";
              example = "https://control2.example.com:10260";
            };
          };
        }
      );
      default = [ ];
      description = "Signers of the other API servers, whose keys to trust.";
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      default = config.services.spire.agent.settings.agent.socket_path;
      defaultText = lib.literalExpression "config.services.spire.agent.settings.agent.socket_path";
      description = "Path to the SPIFFE Workload API socket.";
    };
  };

  config = lib.mkIf cfg.enable {
    kubernetes.kube-apiserver.args.service-account-signing-endpoint = cfg.socket;

    systemd.services.kube-jwt-signer = {
      description = "Kubernetes service account token signer";
      wantedBy = [ "multi-user.target" ];
      before = [ "kube-apiserver.service" ];
      requiredBy = [ "kube-apiserver.service" ];
      environment.SPIFFE_ENDPOINT_SOCKET = "unix://${cfg.socketPath}";
      serviceConfig = {
        Type = "notify";
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "-socket"
            cfg.socket
            "-key-dir"
            "/var/lib/kube-jwt-signer/keys"
            "-rotation-period"
            cfg.rotationPeriod
            "-listen"
            "[::]:${toString cfg.port}"
          ]
          ++ lib.concatMap (peer: [
            "-peer"
            "${peer.spiffeID},${peer.url}"
          ]) cfg.peers
        );
        Restart = "on-failure";
        RestartSec = "5s";
        RuntimeDirectory = "kube-jwt-signer";
        StateDirectory = "kube-jwt-signer";
        StateDirectoryMode = "0700";
        UMask = "0077";
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
