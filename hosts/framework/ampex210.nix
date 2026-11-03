{pkgs,...}:
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

  # The terminal runs in its native Ampex mode, which vpagent targets.
  # man renders badly with it, most likely because the entry declares xmc#1:
  # every bold and underline costs a character cell, so the columns of a man
  # page drift.
  boot.kernelParams = [
    "systemd.tty.term.ttyUSB0=ampex210"
  ];

  # Changes from nixpkgs:
  # 1. no explicit loginProgram (util-linux agetty already sets it?)
  #    (Though we currently patch it to use shadow?)
  # 2. No @I;  instead use - as stdin is connected to the tty
  /*systemd.services."serial-getty@".serviceConfig.ExecStart = [
    ""
    "${pkgs.util-linux}/bin/agetty --no-reset --noclear --issue-file=/etc/issue 9600 - $${TERM}"
  ];*/
  
  # TODO: all the agetty stuff
}
