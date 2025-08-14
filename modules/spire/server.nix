{
  lib,
  pkgs,
  config,
  utils,
  ...
}:

{
  options.spire.server = {
    enable = lib.mkEnableOption "SPIRE server";

    config = lib.mkOption {
      type = lib.types.str;
      description = "SPIRE config";
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

  };
  config = lib.mkIf config.spire.server.enable {
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
        # TODO: FHS
        ListenStream = "/run/spire-server/private/api.sock";
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
        StateDirectory = "spire-server";
        ExecStart =
          utils.escapeSystemdExecArgs (
            [
              "${pkgs.spire}/bin/spire-server"
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
              config = pkgs.writeText "server.hcl" config.spire.server.config;
            })
          )
          + " --dataDir $STATE_DIRECTORY";

      };
    };
  };
}
