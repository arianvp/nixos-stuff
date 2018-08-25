{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.yubico-piv-tool
    pkgs.yubioath-desktop
  ];

  # Enable smartcard daemon, to read TOPT tokens from yubikey
  services.pcscd.enable = true;

  # Enable u2f over USB, for yubikey auth in browser
  hardware.u2f.enable = true;


  # Allow for storing your SSH key on yubikey
  programs.ssh.extraConfig = ''
  PKCS11Provider=${pkgs.yubico-piv-tool}/lib/libykcs11.so
  '';
}
