{ ... }:
{
  imports = [ ../../modules/nix/m4.nix ];

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
