{ lib, pkgs, ... }:
lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
  # sshfs is here for ad-hoc mounts; there is deliberately no permanent mount
  # unit for altra. A user manager cannot set up autofs (that needs
  # CAP_SYS_ADMIN), so such a unit can only ever be an eager mount, and a
  # dropped connection then leaves sshfs mounted and serving EIO. Anything
  # enumerating mounts stalls on that: gvfs-udisks2-volume-monitor sniffs the
  # mount for autorun.inf and friends, each probe blocking up to ~2s, which
  # delays every nautilus launch by several seconds.
  home.packages = [ pkgs.sshfs ];

  # eDP-1 is 1504 logical px wide, so a half-screen niri column is 728 px.
  # At 12pt JetBrains Mono (9.5 px/cell) that is only 76 columns; 11pt fits 83.
  programs.ghostty = {
    enable = true;
    settings.font-size = 11;
  };
}
