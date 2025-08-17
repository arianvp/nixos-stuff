{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.spire.oidc-discovery-provider;
  description = "SPIRE OIDC Provider";

  config = ''
    acme {

    }
  '';
in
{
  options.spire.oidc-discovery-provider = {
    enable = lib.mkEnableOption description;
  };

  config = lib.mkIf cfg.enable {
    systemd.services.oidc-discovery-provider = {
      inherit description;
      wantedBy = [ "multi-user.target" ];
      # TODO: move into own output?
      serviceConfig.ExecStart = "${pkgs.spire}/bin/oidc-discovery-provider";
    };
  };
}
