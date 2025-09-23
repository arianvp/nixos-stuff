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
  format = hcl1 {};
in
{
  options.spire.server = {
    enable = lib.mkEnableOption "SPIRE server";


    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
      };
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "server.conf" cfg.settings;
      description = "Path to SPIRE config file";
    };

    expandEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expand environment variables in SPIRE config file";
    };

    logFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "File to write logs to";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [
        "debug"
        "info"
        "warn"
        "error"
      ];
      default = "info";
      description = "Log level";
    };

    logSourceLocation = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include source file, line number and function name in log lines";
    };

    trustDomain = lib.mkOption {
      type = lib.types.str;
      description = "The trust domain that this server belongs to";
    };

    socketPath = lib.mkOption {
      type = lib.types.str;
      description = "Path to bind the SPIRE Server API Socket to";
      default = "/run/spire/server/private/api.sock";
    };

  };
  config = lib.mkIf cfg.enable {
    # NOTE: for https://github.com/spiffe/spire/issues/5770
    systemd.globalEnvironment.SPIRE_SERVER_ADMIN_SOCKET = cfg.socketPath;
    environment.variables.SPIRE_SERVER_ADMIN_SOCKET = cfg.socketPath;
    environment.systemPackages = [ pkgs.spire ];
    networking.firewall.allowedTCPPorts = [
      443
      8081
    ];
    systemd.sockets.spire-server = {
      description = "Spire Server API Socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "8081";
        FileDescriptorName = "spire-server-tcp";
        Service = "spire-server.service";
      };
    };
    systemd.sockets.spire-server-local = {
      description = "Spire Server Local API Socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = cfg.socketPath;
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
        RuntimeDirectory = "spire-server";
        CacheDirectory = "spire-server";
        StateDirectory = "spire-server";
        StateDirectoryMode = "0700";
        ExecStart =
          utils.escapeSystemdExecArgs (
            [
              "${pkgs.spire.server}/bin/spire-server"
              "run"
            ]
            ++ (lib.cli.toGNUCommandLine { } {
              inherit (config.spire.server)
                expandEnv
                logFile
                logLevel
                logSourceLocation
                trustDomain
                ;
              config = cfg.configFile;
            })
          )
          + " --dataDir $STATE_DIRECTORY";

      };
    };
  };
}
