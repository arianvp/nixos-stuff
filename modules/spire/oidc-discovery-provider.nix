{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.spire.oidc-discovery-provider;
  inherit (import ./hcl1-format.nix { inherit pkgs lib; }) hcl1;
  format = hcl1 { };
in
{
  options.spire.oidc-discovery-provider = {

    enable = lib.mkEnableOption "SPIRE OIDC Discovery Provider";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.spire.oidc;
      defaultText = lib.literalExpression "pkgs.spire.oidc";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          domains = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Domain names the provider answers requests for.";
          };
        };
      };
      description = ''
        OIDC Discovery Provider configuration. See
        <https://github.com/spiffe/spire/blob/main/support/oidc-discovery-provider/README.md>.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "oidc-discovery-provider.conf" cfg.settings;
      defaultText = "A file generated from spire.oidc-discovery-provider.settings";
    };

    expandEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

  };

  config = lib.mkIf cfg.enable {

    spire.oidc-discovery-provider.settings = {
      workload_api =
        lib.mkIf (config.services.spire.agent.enable && !config.services.spire.server.enable)
          {
            socket_path = lib.mkDefault config.services.spire.agent.settings.agent.socket_path;
            trust_domain = lib.mkDefault config.services.spire.agent.settings.agent.trust_domain;
          };
      server_api = lib.mkIf config.services.spire.server.enable {
        address = lib.mkDefault "unix://${config.services.spire.server.settings.server.socket_path}";
      };
    };

    systemd.services.spire-oidc-discovery-provider = {
      description = "SPIRE OIDC Discovery Provider";
      wantedBy = [ "multi-user.target" ];
      after = lib.optional config.services.spire.server.enable "spire-server.service";
      restartTriggers = [ cfg.configFile ];
      serviceConfig = {
        ExecStart =
          "${lib.getExe' cfg.package "oidc-discovery-provider"} "
          + lib.cli.toCommandLineShellGNU { } {
            inherit (cfg) expandEnv;
            config = cfg.configFile;
          };
        Restart = "on-failure";
        RestartSec = "5s";
        CacheDirectory = "spire-oidc-discovery-provider";
      };
    };
  };
}
