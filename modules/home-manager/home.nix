{ lib, pkgs, ... }:
{

  imports = [ ./jj ];

  programs.noctalia-shell = {
    systemd.enable = true;
    settings = {
    };
    # this may also be a string or a path to a JSON file.
  };

  home.stateVersion = "26.05";
}
