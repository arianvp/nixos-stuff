{ lib, pkgs, ... }:
{

  imports = [ ./jj ./claude-code.nix ];

  programs.noctalia-shell = {
    systemd.enable = true;
    settings = {
    };
    # this may also be a string or a path to a JSON file.
  };

  programs.direnv.enable = true;


  home.stateVersion = "26.05";
}
