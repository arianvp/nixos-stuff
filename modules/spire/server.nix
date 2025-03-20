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
      default = "127.0.0.1";
    };

    config = lib.mkOption {
      type = lib.types.str;
      description = "SPIRE config";
      default = ''
        server {
          federation {
            bundle_endpoint {
              address = "0.0.0.0"
              port = 443
              profile "https_web" {
                acme {
                  domain_name = "${config.spire.server.trustDomain}"
                  tos_accepted = true
                }
              }
            }
          }
        }
        plugins {
          KeyManager "memory" {
            plugin_data {
            }
          }
          DataStore "sql" {
            plugin_data {
              database_type = "sqlite3"
              connection_string = "$STATE_DIRECTORY/datastore.sqlite3"
            }
          }
          NodeAttestor "http_challenge" {
            plugin_data {
            }
          }
          NodeAttestor "join_token" {
            plugin_data {
            }
          }
        }
      '';
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
      type = lib.types.str;
      description = "Path to bind the SPIRE Server API socket to";
      default = "/run/spire-server.sock";
    };

    trustDomain = lib.mkOption {
      type = lib.types.str;
      description = "The trust domain that this server belongs to";
    };

  };
  config = lib.mkIf config.spire.server.enable {
    environment.systemPackages = [ pkgs.spire ];
    systemd.services.spire-server = {
      description = "Spire Server";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
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
