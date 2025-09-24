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

    # TODO: separate output for oidc-discovery-provider
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.spire;
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          workload_api = {
            trust_domain = lib.mkOption {
              type = lib.types.str;
            };
            socket_path = lib.mkOption {
              type = lib.types.str;
            };
          };
        };
      };
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "oidc-discovery-provider.conf" cfg.settings;
    };

    expandEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

  };

  config = lib.mkIf cfg.enable {

    spire.oidc-discovery.provider.settings = {
      workload_api = lib.mkIf (config.spire.agent.enable) {
        socket_path = lib.mkDefault config.spire.agent.settings.socket_path;
        trust_domain = lib.mkDefault config.spire.agent.options.trust_domain;
      };
      server_api = lib.mkIf (config.spire.server.enable && !config.spire.agent.enable) {
        address = lib.mkDefault config.spire.server.settings.socket_path;
      };
    };

    systemd.services.spire-oidc-discovery-provider =
      { name, ... }:
      {
        description = "SPIRE OIDC Discovery Provider";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          # TODO: separate output
          ExecStart =
            "${lib.getExe' cfg.package "oidc-discovery-provider"}"
            + lib.cli.toGNUCommandLineShell { } {
              inherit (cfg) expandEnv;
              config = cfg.configFile;
            };
          Restart = "on-failure";
          CacheDirectory = name;
        };
      };
  };
}
