# Adds an ESP to the disk image of ./verity-store.nix, holding a single UKI
# at the path that firmware boots without a boot entry:
#
#   ESP    /EFI/BOOT/BOOT<arch>.EFI  kernel, initrd and a command line that
#                                    pins the root hash of the store
#
# The firmware measures the UKI into PCR4 before running it, so PCR4 commits to
# every byte of the system.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.stdenv) hostPlatform;
in
{
  imports = [ ./verity-store.nix ];

  image.repart = {
    verityStore.ukiPath = "/EFI/BOOT/BOOT${lib.toUpper hostPlatform.efiArch}.EFI";
    partitions.${config.image.repart.verityStore.partitionIds.esp}.repartConfig = {
      Type = "esp";
      Format = "vfat";
      SizeMinBytes = if hostPlatform.isx86_64 then "64M" else "96M";
    };
  };
}
