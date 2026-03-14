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

  environment.etc.inputrc.text= ''
  $if term=ampex210
  set enable-bracketed-paste off
  $endif
  $if term=addsviewpoint
  set enable-bracketed-paste off
  $endif
  '';

  # NOTE: I set it to addsviewpoint mode as it seems to work better with `man`
  # as the ampex210 terminfo makes man not render correctly
  boot.kernelParams = [
    "systemd.tty.term.ttyUSB0=addsviewpoint"
  ];

  # Changes from nixpkgs:
  # 1. no explicit loginProgram (util-linux agetty already sets it?)
  #    (Though we currently patch it to use shadow?)
  # 2. No @I;  instead use - as stdin is connected to the tty
  systemd.services."serial-getty@".serviceConfig.ExecStart = [
    ""
    "${pkgs.util-linux}/bin/agetty --no-reset --noclear --issue-file=/etc/issue --keep-baud 19200,9600 - $${TERM}"
  ];
  
  # TODO: all the agetty stuff
}
