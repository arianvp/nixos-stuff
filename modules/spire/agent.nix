{
  lib,
  utils,
  pkgs,
  config,
  ...
}:
let
  cfg = config.spire.agent;
  inherit (import ./hcl1-format.nix { inherit pkgs lib; }) hcl1;
  format = hcl1 { };
in
{
  options.spire.agent = {
    enable = lib.mkEnableOption "Spire agent";

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;
        options.agent = {
          trust_domain = lib.mkOption {
            type = lib.types.str;
            description = "The trust domain that this agent belongs to";
          };
          data_dir = lib.mkOption {
            type = lib.types.str;
            default = "$STATE_DIRECTORY";
            description = "The directory where the SPIRE agent stores its data";
          };
          server_address = lib.mkOption {
            type = lib.types.str;
            description = "The address of the SPIRE server";
          };
          server_port = lib.mkOption {
            type = lib.types.int;
            default = 8081;
            description = "The port on which the SPIRE server is listening";
          };
          socket_path = lib.mkOption {
            type = lib.types.path;
            default = "/run/spire/agent/public/api.sock";
            description = "The path to the SPIRE agent socket";
          };
        };
      };
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = format.generate "agent.conf" cfg.settings;
    };

    expandEnv = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expand environment variables in SPIRE config file";
    };

  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.spire-agent ];

    # NOTE: For when https://github.com/spiffe/spire/pull/5776 lands
    environment.variables.SPIFFE_ENDPOINT_SOCKET = cfg.settings.agent.socket_path;
    systemd.globalEnvironment.SPIFFE_ENDPOINT_SOCKET = cfg.settings.agent.socket_path;

    systemd.sockets.spire-agent = {
      description = "Spire agent API socket";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        FileDescriptorName = "spire-agent-workload";
        ListenStream = cfg.settings.agent.socket_path;
      };
    };

    systemd.services.spire-agent = {
      description = "Spire agent";
      serviceConfig = {
        Restart = "always";
        RuntimeDirectory = "spire-agent";
        StateDirectory = "spire-agent";
        StateDirectoryMode = "0700";
        ExecStart = utils.escapeSystemdExecArgs (
          [
            "${pkgs.spire.agent}/bin/spire-agent"
            "run"
          ]
          ++ (lib.cli.toGNUCommandLine { } {
            inherit (cfg) expandEnv;
            config = cfg.configFile;
          })
        );

        # NOTE: We must run as root as unix plugin relies on accessing system bus and /proc

        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;

        # TODO: might be needed by tpm plugin
        # PrivateDevices = true;
        DeviceAllow = "/dev/tpmrm0";
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        UMask = "0600";
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = "AF_UNIX AF_INET AF_INET6";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
      };
    };
  };
}
