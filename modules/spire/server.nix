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

    bindAddress = lib.mkOption {
      type = lib.types.str;
      description = "IP address or DNS name of the SPIRE server";
      default = "0.0.0.0";
    };

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

    serverPort = lib.mkOption {
      type = lib.types.port;
      description = "Port number of the SPIRE server";
      default = 8081;
    };

    socketPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      description = "Path to bind the SPIRE Server API socket to";
      default = null;
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
    systemd.services.spire-server = {
      description = "Spire Server";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
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
                bindAddress
                expandEnv
                logFile
                logLevel
                logSourceLocation
                serverPort
                socketPath
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
