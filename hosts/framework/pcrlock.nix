{ pkgs, config, ... }:

let
  bootLoaderLock = pkgs.runCommand "240-boot-loader.pcrlock" { } ''
    ${config.systemd.package}/lib/systemd-pcrlock lock-pe 
  '';

in
{

  boot.lanzaboote = {
    configurationLimit = 8;
    measuredBoot = {
      enable = true;
      pcrs = [
        0
        # 1  # das ist kaka slopper.  It seems that the SMBIOS measurements are not reproducible across boots
        2 # I have no option roms
        3 # I have no option roms 
        4 # systemd-boot and UKIs
        7
      ];
    };
  };

}
