{ config, pkgs, lib, ...}:
{
  services.weechat.enable = true;
  programs.screen.screenrc = ''
    multiuser on
    acladd normal_user
  '';
}
