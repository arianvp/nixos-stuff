{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  dataDir = "/var/lib/nomad";
  cfg = config.services.nomad;
in
{
  options = {
    services.nomad = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "enable nomad cluster";

      };
      extraConfig = mkOption {
        default = { };
        description = ''
          Extra configuration options which are serialized to json and added
          to the config.json file.
        '';
      };
    };
  };
  config =
    let
      nomadFile = config.environment.etc."nomad.json".source;
    in
    mkIf cfg.enable {
      environment.etc."nomad.json".text = builtins.toJSON ({ data_dir = dataDir; } // cfg.extraConfig);
      environment.systemPackages = [ pkgs.nomad ];
      systemd.services.nomad = {
        path = with pkgs; [
          iproute
          gnugrep
          gawk
          nomad
        ];
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        restartTriggers = [ config.environment.etc."nomad.json".source ];
        serviceConfig = {
          ExecStart = "@${pkgs.nomad}/bin/nomad nomad agent -config=${nomadFile}";
          Restart = "on-failure";
        };
        preStart = ''
          mkdir -m 0700 -p ${dataDir}
        '';
      };
    };
}
