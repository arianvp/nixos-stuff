{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.virtualisation.digitalOceanImage;
in
{

  imports = [ ./config.nix ];

  options = {
    virtualisation.digitalOceanImage.diskSize = mkOption {
      type = with types; int;
      default = 4096;
      description = ''
        Size of disk image. Unit is MB.
      '';
    };
  };

  #### implementation
  config = {

    system.build.digitalOceanImage = import <nixos-19.03/nixos/lib/make-disk-image.nix> {
      name = "digital-ocean-image";
      format = "qcow2";
      postVM = ''
        ${pkgs.gzip}/bin/gzip $diskImage
      '';
      # configFile = if isNull cfg.configFile then defaultConfigFile else cfg.configFile;
      inherit (cfg) diskSize;
      inherit config lib pkgs;
    };

  };

}
