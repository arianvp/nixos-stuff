{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.kubernetes.etcd;
  format = pkgs.formats.yaml { };
in
{
  options.kubernetes.etcd = {
    enable = lib.mkEnableOption "etcd";

    package = lib.mkPackageOption pkgs "etcd" { };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            default = config.networking.hostName;
            defaultText = lib.literalExpression "config.networking.hostName";
            description = "Human-readable name for this member.";
          };
          data-dir = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/etcd";
            readOnly = true;
            description = "Path to the data directory.";
          };
        };
      };
      default = { };
      description = ''
        etcd configuration file. Passing a configuration file makes etcd ignore
        all command-line flags and environment variables.
        See <https://etcd.io/docs/latest/op-guide/configuration/>.
      '';
      example = lib.literalExpression ''
        {
          listen-client-urls = "https://[::]:2379";
          advertise-client-urls = "https://etcd.example.com:2379";
          client-transport-security = {
            cert-file = "/run/etcd-svid/svid.pem";
            key-file = "/run/etcd-svid/svid.key";
            trusted-ca-file = "/etc/ssl/spire-bundle.pem";
            client-cert-auth = true;
          };
        }
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "etcd.yaml" cfg.settings;
      defaultText = "A file generated from kubernetes.etcd.settings";
      description = "etcd configuration file.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.etcd = {
      description = "etcd key-value store";
      documentation = [ "https://etcd.io/docs/" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      restartTriggers = [ cfg.configFile ];
      serviceConfig = {
        Type = "notify";
        ExecStart = "${lib.getExe' cfg.package "etcd"} --config-file ${cfg.configFile}";
        StateDirectory = "etcd";
        StateDirectoryMode = "0700";
        Restart = "on-failure";
        RestartSec = "5s";
        LimitNOFILE = 65536;
      };
    };
  };
}
