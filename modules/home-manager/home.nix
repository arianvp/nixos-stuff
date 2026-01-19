{ lib, pkgs, ... }:
{
  programs.jujutsu = {
    enable = true;
    settings = {
      ui.default-command = "log";
      user.name = "Arian van Putten";
      user.email = "arian@arianvp.me";

      fix.tools.nixfmt = {
        command = [ (lib.getExe pkgs.nixfmt) ];
        patterns = [ "glob:'**/*.nix'" ];
      };
      signing = {
        behavior = "drop";
        backend = "ssh";
        # TODO: point to whatever yubikey is inserted. I wonder if we can do this with udev
        key = "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIJfMczLTlN0csX8HFFneaYW6OH0lupwCryoDANaqR6lxAAAABHNzaDo=";
      };
      git.sign-on-push = true;
    };
  };
  home.stateVersion = "26.05";
}
