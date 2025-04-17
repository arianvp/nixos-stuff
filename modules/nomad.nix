{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nomad2;
  format = pkgs.formats.json { };
in
{
  options.services.nomad2 = {
    enable = lib.mkEnableOption "nomad";
    package = lib.mkPackageOption pkgs "nomad" { };
    settings = lib.mkOption {
      type = format.type;
      default = {
        data_dir = "/var/lib/nomad";
      };
    };
  };

  config.systemd.services.nomad = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "notify"; # TODO: notify-reload
      ExecStart = "${cfg.package}/bin/nomad agent -config ${format.generate "nomad.json" cfg.settings}";
      StateDirectory = "nomad";
    };
  };
}
