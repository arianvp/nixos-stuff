{ pkgs, ... }:
{

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Makes nix-darwin add `/etc/profiles/per-user/$USER/bin` and
  # `/run/current-system/sw/bin` to PATH, so home-manager-installed
  # packages (via `home.packages`) are actually on PATH.
  programs.zsh.enable = true;

  system.primaryUser = "arian";

  users.users.arian.home = "/Users/arian";

  nix.enable = true;
  nix.package = pkgs.lixPackageSets.latest.lix;
  nix.settings.trusted-users = [ "arian" ];
  nix.settings.allowed-users = [ "arian" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
