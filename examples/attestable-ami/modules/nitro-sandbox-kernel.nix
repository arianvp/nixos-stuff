# A kernel for Nitro Sandbox parents: nixpkgs' 6.18 with AWS's extension of
# the Nitro Enclaves driver, which launches sandboxes.
{ lib, pkgs, ... }:
{
  boot.kernelPackages = pkgs.linuxPackages_6_18;
  boot.kernelPatches = [
    {
      name = "nitro-enclaves-extension";
      patch = pkgs.callPackage ./nitro-sandbox-patch.nix { };
      structuredExtraConfig = with lib.kernel; {
        # Reserves the memory pool early in boot.
        NITRO_ENCLAVES = yes;
        PARAVIRT_GUEST_CLOCK = yes;
      };
    }
  ];
}
