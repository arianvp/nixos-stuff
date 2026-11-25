# Puts the Nix store on its own partitions, as erofs under dm-verity, and
# mounts it on /usr:
#
#   store-verity   dm-verity hash tree of the store
#   store          the Nix store as erofs
#
# The kernel command line carries the hash tree's root hash (`usrhash=`), so
# whatever measures the command line commits to every byte of the store, and a
# block that doesn't match the hash can't be read.
{ modulesPath, ... }:
{
  imports = [ "${modulesPath}/image/repart.nix" ];

  image.repart = {
    enable = true;
    verityStore.enable = true;
  };

  # /usr is the read-only store.
  environment.usrbinenv = null;

  # Corrupted store blocks read as I/O errors by default. Stop the machine
  # instead of letting it run on with parts of the system missing.
  boot.kernelParams = [ "systemd.verity_usr_options=panic-on-corruption" ];
}
