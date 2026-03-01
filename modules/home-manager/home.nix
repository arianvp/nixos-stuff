{ lib, pkgs, ... }:
{

  imports = [ ./jj ];

  nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "claude-code" ];

  programs.noctalia-shell = {
    systemd.enable = true;
    settings = {
    };
    # this may also be a string or a path to a JSON file.
  };

  programs.direnv.enable = true;

  home.packages = [ pkgs.claude-code ];

  home.stateVersion = "26.05";
}
