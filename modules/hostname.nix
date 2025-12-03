{config, lib, ...}:
let
  cfg = config.networking.dynamicHostName;
in
{
  options.networking.dynamicHostName = {
    enable = lib.mkEnableOption "automatic hostname management based on system.name";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.networking.hostName == "";
        message = "networking.hostName cannot be set when networking.dynamicHostName is enabled. This module manages the hostname automatically.";
      }
    ];

    environment.etc.hostname.text = "${config.system.name}-????-????";
  };
}
