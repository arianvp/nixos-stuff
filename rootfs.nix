{ config, lib, pkgs, utils, ...}:
with pkgs.lib;
with utils;
with config.arian.rootfs;
let
  mkfs = options: {
    inherit device;
    fsType = "btrfs";
    options = [
      "noatime"
      "nodiratime"
      "compress=zstd"   # NOTE: This might fail to mount on old Kernels
      "discard"         # Needed for ssd
      "defaults"
    ] ++ options;
  };
  fullMount = "/mnt/rootfs";
in
{
  options = {
    arian.rootfs = {
      device = mkOption { type = types.string; };
    };
  };
  config = {
    services.btrfs.autoScrub = {
      enable = true;
      fileSystems = [ fullMount ];
    };
    fileSystems = {
      "/"            = mkfs ["subvol=@"];
      "/home"        = mkfs ["subvol=@home"];
      "/nix"         = mkfs ["subvol=@nix"];
      "/var"         = mkfs ["subvol=@var"];
      "/etc/nixos"   = mkfs ["subvol=@nixos"]; 
      "${fullMount}" = mkfs [];
    };
  };
}
