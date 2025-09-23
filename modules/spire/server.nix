{
  lib,
  pkgs,
  config,
  utils,
  ...
}:
let
  cfg = config.spire.server;
  inherit (import ./hcl1-format.nix { inherit pkgs lib; }) hcl1;
  format = hcl1 { };
in
{
  options.spire.server = {
    enable = lib.mkEnableOption "SPIRE server";

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options.server = {
          trust_domain = lib.mkOption {
            type = lib.types.str;
            description = "The trust domain that this server belongs to";
          };
          data_dir = lib.mkOption {
            type = lib.types.str;
            description = "The directory where SPIRE server stores its data";
            default = "$STATE_DIRECTORY";
          };
          socket_path = lib.mkOption {
            type = lib.types.str;
            default = "/run/spire/server/private/api.sock";
            description = "Path to bind the SPIRE Server API Socket to";
          };
          bind_address = lib.mkOption {
            type = lib.types.str;
            default = "[::]";
            description = "The address on which the SPIRE server is listening";
          };
          bind_port = lib.mkOption {
            type = lib.types.port;
            default = 8081;
            description = "The port on which the SPIRE server is listening";
          };
        };
      };
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "server.conf" cfg.settings;
      description = "Path to the SPIRE server configuration file";
    };

    expandEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expand environment variables in SPIRE config file";
    };

  };
  config = lib.mkIf cfg.enable {
    # NOTE: for https://github.com/spiffe/spire/issues/5770
    systemd.globalEnvironment.SPIRE_SERVER_ADMIN_SOCKET = cfg.settings.server.socket_path;
    environment.variables.SPIRE_SERVER_ADMIN_SOCKET = cfg.settings.server.socket_path;
    environment.systemPackages = [ pkgs.spire ];
    networking.firewall.allowedTCPPorts = [
      443
      8081
    ];
    systemd.sockets.spire-server = {
      description = "Spire Server API Socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "${cfg.settings.server.bind_address}:${toString cfg.settings.server.bind_port}";
        FileDescriptorName = "spire-server-tcp";
        Service = "spire-server.service";
      };
    };
    systemd.sockets.spire-server-local = {
      description = "Spire Server Local API Socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = cfg.settings.server.socket_path;
        SocketMode = "0600";
        FileDescriptorName = "spire-server-local";
        Service = "spire-server.service";
      };
    };
    systemd.services.spire-server = {
      description = "Spire Server";
      serviceConfig = {
        Sockets = [
          "spire-server.socket"
          "spire-server-local.socket"
        ];
        Restart = "on-failure";
        CacheDirectory = "spire-server";
        StateDirectory = "spire-server";
        StateDirectoryMode = "0700";
        ExecStart = utils.escapeSystemdExecArgs (
          [
            "${pkgs.spire.server}/bin/spire-server"
            "run"
          ]
          ++ (lib.cli.toGNUCommandLine { } {
            inherit (cfg) expandEnv;
            config = cfg.configFile;
          })
        );

      };
    };
  };
}
