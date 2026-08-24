{ ... }:
{
  # Needs macOS 15+ and an M3 or newer chip. The builder VM then boots at EL2
  # and gets a real /dev/kvm, so NixOS VM tests run at native speed instead of
  # falling back to TCG emulation.
  #
  # TODO: these options not being on the nix-darwin level is really awkward IMO
  nix.linux-builder = {
    supportedFeatures = [ "kvm" ];
    config.virtualisation.vz.nestedVirtualization = true;
  };
}
