{ pkgs, ... }:
{
  programs.noctalia-shell = {
    systemd.enable = true;
    settings = {
    };
    # this may also be a string or a path to a JSON file.
  };

  home.packages = [ pkgs.sshfs ];

  systemd.user = {
    # TODO: Seems automounts don't work unpriveleged
    # Apr 27 11:43:27 framework systemd[2194]: Failed to mount systemd-2194 (type autofs) on /home/arian/altra (0 "fd=98,pgrp=2194,minproto=5,maxproto=5,direct"): Operation not permitted
    # Apr 27 11:43:27 framework systemd[2194]: home-arian-altra.automount: Failed with result 'resources'.
    # Apr 27 11:43:27 framework systemd[2194]: Failed to set up automount home-arian-altra.automount.
    automounts.home-arian-altra = {
      Automount.Where = "/home/arian/altra";
      Install.WantedBy = [ "default.target" ];
    };
    mounts.home-arian-altra = {
      Install.WantedBy = [ "default.target" ];
      Mount = {
        Where = "/home/arian/altra";
        What = "arian@altra.ygg.nixos.sh:/home/arian";
        Type = "fuse.sshfs";
        Options = "_netdev,user,delay_connect,reconnect,ServerAliveInterval=15,dir_cache=yes,idmap=user,follow_symlinks,transform_symlinks,compression=yes";
      };
    };
  };
}
