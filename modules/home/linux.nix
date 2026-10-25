{ lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  home.packages = [ pkgs.sshfs ];

  # eDP-1 is 1504 logical px wide, so a half-screen niri column is 728 px.
  # At 12pt JetBrains Mono (9.5 px/cell) that is only 76 columns; 11pt fits 83.
  programs.ghostty = {
    enable = true;
    settings.font-size = 11;
  };

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
