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

  home.packages = [ pkgs.claude-code pkgs.sshfs ];

  systemd.user = {
    automounts.home-arian-altra = {
      Automount.Where = "/home/arian/altra";
      Install.WantedBy = [ "default.target" ];
    };
    mounts.home-arian-altra.Mount = {
      Where = "/home/arian/altra";
      What = "arian@altra.ygg.nixos.sh:/home/arian";
      Type = "fuse.sshfs";
      Options = "_netdev,user,delay_connect,reconnect,ServerAliveInterval=15,dir_cache=yes,idmap=user,follow_symlinks,transform_symlinks,compression=yes";
    };
  };

  home.stateVersion = "26.05";
}
