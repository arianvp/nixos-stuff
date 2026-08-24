{ ... }:
{
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;

  # This one is an M4 on macOS 26, so the builder VM can boot at EL2 and get a
  # real /dev/kvm. That is what makes NixOS integration tests run here at native
  # speed instead of falling back to TCG emulation.
  nix.linux-builder = {
    supportedFeatures = [ "kvm" ];
    config.virtualisation.vz.nestedVirtualization = true;
  };
}
