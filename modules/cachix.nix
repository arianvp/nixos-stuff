{...}: {
  nix = {
    binaryCaches = [
      "https://cache.nixos.org/"
      "https://hie-nix.cachix.org"
      "https://arianvp.cachix.org"
    ];
    binaryCachePublicKeys = [
      "hie-nix.cachix.org-1:EjBSHzF6VmDnzqlldGXbi0RM3HdjfTU3yDRi9Pd0jTY="
      "arianvp.cachix.org-1:/NYL/rC71vauTeFWVMJXXadA/2MfziDb+/1DlLLXUvw="
    ];
    trustedUsers = [ "root" "arian" ];
  };
}
