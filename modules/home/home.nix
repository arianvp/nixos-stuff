{ lib, pkgs, ... }:
{

  imports = [
    ./jj
    ./claude-code.nix
  ];

  programs.noctalia-shell = {
    systemd.enable = true;
    settings = {
    };
    # this may also be a string or a path to a JSON file.
  };

  programs.direnv.enable = true;

  home.packages = [ pkgs.claude-code ];

  systemd.user = {
    automounts.altra = {
      Automount.Where = "%h/altra";
      Install.WantedBy = [ "default.target" ];
    };
    mounts.altra.Mount = {
      Where = "%h/altra";
      What = "arian@altra.ygg.nixos.sh:/home/arian";
      Type = "sshfs";
      Options = "reconnect,ServerAliveInterval=15,dir_cache=yes,idmap=user,follow_symlinks,transform_symlinks,compression=yes";
    };
  };

  home.stateVersion = "26.05";
}
