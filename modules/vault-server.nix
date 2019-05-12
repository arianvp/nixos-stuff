{ pkgs, lib, config, ...}:
let
  cfg = config.services.vault-server;
  serverConfig = pkgs.writeText "vault-server.hcl" (builtins.toJSON cfg.config);
in {
  options.services.vault-server = {
    config = lib.options.mkOption {
      type = lib.types.attrs;
      default = {};
    };
  };
  config = {
    systemd.services.vault-server = {
      serviceConfig = {
        ExecStart = "${pkgs.vault}/bin/vault server -config ${serverConfig}";
        StateDirectory = "vault";
        DynamicUser = true;
        User = "vault";
        Group = "vault";
        PrivateDevices = true;
        CapabilityBoundingSet = ["CAP_SYSLOG" "CAP_IPC_LOCK" ];
        AmbientCapabilities = ["CAP_IPC_LOCK"];
        KillSignal = "SIGINT";
        Restart = "on-failure";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
