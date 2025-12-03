{config, lib, ...}:
let
  cfg = config.networking.dynamicHostName;
in
{
  options.networking.dynamicHostName = {
    enable = lib.mkEnableOption "automatic hostname management based on system.name";
  };

  config = lib.mkIf cfg.enable {
    networking.hostName = "";
    environment.etc.hostname.text = "${config.system.name}-????-????";
  };
}
