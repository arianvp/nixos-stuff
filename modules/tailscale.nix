{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.services.tailscale.funnel;
in
{
  options = {
    services.tailscale.tailnet.name = lib.mkOption {
      type = lib.types.string;
      default = "bunny-minnow.ts.net";
    };

    services.tailscale.funnel = {
      enable = lib.mkEnableOption "Enable Tailscale Funnel service";
      target = lib.mkOption {
        type = lib.types.string;
      };
    };
  };

  config = {
    services.tailscale.enable = true;

    systemd.services.tailscale-funnel = lib.mkIf cfg.enable {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.tailscale}/bin/tailscale funnel ${cfg.target}";
        Restart = "always";
      };
    };
  };
}
