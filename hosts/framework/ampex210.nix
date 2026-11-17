{ config, pkgs, utils, ... }:
let
  # The adapter by its serial number, whichever ttyUSB it comes up as.
  port = "serial/by-id/usb-Prolific_Technology_Inc._USB-Serial_Controller_ATALb147613-if00-port0";
in
{

  # Simple prompt for ampex210 terminal compatibility
  programs.bash.promptInit = ''
    PS1='\u@\h:\w\$ '
  '';

  # Default issue has escape codes we do not support
  environment.etc.issue.text = ''
    Welcome to \S on \n \l.
    You can reach me at \6.
    The current time is \t.
    There are currently \U logged in.
  '';

  # neovim seems to not handle old terminals well. vim does
  environment.systemPackages = [ pkgs.vim ];

  # The ampex210's arrows send single control characters (up ^K, down ^V,
  # right ^L, left ^H) that the emacs keymap already binds, and readline only
  # learns terminfo's arrow keys where the sequence is still free, so they are
  # bound by hand. Left stays backspace: the terminal sends ^H for both.
  environment.etc.inputrc.text= ''
  $if term=ampex210
  set enable-bracketed-paste off
  "\C-k": previous-history
  "\C-v": next-history
  "\C-l": forward-char
  $endif
  $if term=addsviewpoint
  set enable-bracketed-paste off
  $endif
  '';

  # With INPUTRC unset, readline reads ~/.inputrc instead of /etc/inputrc, not
  # as well. home-manager's ~/.inputrc includes the system file, which is what
  # makes the blocks above reach a login shell.
  home-manager.users.arian.programs.readline.enable = true;

  # The getty generator only starts gettys on serial consoles, so this one
  # starts whenever the adapter is plugged in. serial-getty@ passes $TERM to
  # agetty, which hands it to login and the PAM session. With TERM=dumb,
  # systemd neither resets the terminal when the getty starts nor writes OSC
  # 3008 contexts for the service and the session, none of which the 210
  # understands.
  #
  # The drop-in is named overrides.conf, like the one NixOS gives the
  # template, and so replaces it: the template's ExecStart is repeated here.
  systemd.services."serial-getty@${utils.escapeSystemdPath port}" = {
    overrideStrategy = "asDropin";
    serviceConfig.ExecStart = config.systemd.services."serial-getty@".serviceConfig.ExecStart;
    wantedBy = [ "${utils.escapeSystemdPath "/dev/${port}"}.device" ];
    environment.TERM = "dumb";
  };

  # The shell then runs the terminal in its native Ampex mode, which vpagent
  # targets. man renders badly with it, most likely because the entry declares
  # xmc#1: every bold and underline costs a character cell, so the columns of
  # a man page drift. systemd tools started from the shell would emit colours,
  # hyperlinks and window titles again, so those are turned off.
  programs.bash.loginShellInit = ''
    if [ "$TERM" = dumb ] && [ "$(tty)" = "$(readlink -f /dev/${port})" ]; then
      export TERM=ampex210
      export SYSTEMD_COLORS=0 SYSTEMD_URLIFY=0 SYSTEMD_ADJUST_TERMINAL_TITLE=0
    fi
  '';
}
