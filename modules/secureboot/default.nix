

{ lib, pkgs, config, ...}: {
  boot.loader.systemd-boot = {
    enable = true;
  };
}
