{ pkgs, lib, ... }: {
  environment.systemPackages = with pkgs; [
    yubico-piv-tool # superseded by
    yubioath-desktop
    yubikey-manager-qt
    yubikey-manager
  ];

  # Enable smartcard daemon, to read TOPT tokens from yubikey
  # services.pcscd.enable = true;


  programs.ssh.startAgent = true;

  # programs.ssh.agentPKCS11Whitelist = "${pkgs.opensc}/lib/opensc-pkcs11.so";

  # # Allow for storing your SSH key on yubikey
  # programs.ssh.extraConfig = lib.mkBefore ''
  # PKCS11Provider=${pkgs.opensc}/lib/opensc-pkcs11.so
  # '';

}
