{
  utils,
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.spire.oidc-discovery-provider;

  inherit (import ./hcl1-format.nix { inherit pkgs lib; }) hcl1;
  format = hcl1 {};

  description = "SPIRE OIDC Provider";

in
{
  options.spire.oidc-discovery-provider = {
    enable = lib.mkEnableOption description;

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
      };
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "oidc-discovery-provider.conf" cfg.settings;
    };


    expandEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expand environment variables in SPIRE config file";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.oidc-discovery-provider = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      # TODO: move into own output?
      serviceConfig.ExecStart = utils.escapeSystemdExecArgs (
        [
          "${pkgs.spire}/bin/oidc-discovery-provider"
          "run"
        ]
        ++ (lib.cli.toGNUCommandLine { } {
          inherit (cfg) expandEnv;
          config = cfg.configFile;
        })
      );
    };
  };
}
