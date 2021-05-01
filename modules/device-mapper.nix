# Device-mapper and lvm2 are the same package. We don't ship this as a
# multi-output package atm; so just include all of lvm2.
{ config, pkgs, ... }:
{
  config = {
    systemd.tmpfiles.packages = [ pkgs.lvm2.out ];
    systemd.packages = [ pkgs.lvm2 ];
    services.udev.packages = [ pkgs.lvm2.out ];
    environment.systemPackages = [ pkgs.lvm2 ];
  };
}
