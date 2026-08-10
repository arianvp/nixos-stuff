{ ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Makes nix-darwin add `/etc/profiles/per-user/$USER/bin` and
  # `/run/current-system/sw/bin` to PATH, so home-manager-installed
  # packages (via `home.packages`) are actually on PATH.
  programs.zsh.enable = true;

  system.primaryUser = "arian";

  users.users.arian.home = "/Users/arian";
}
