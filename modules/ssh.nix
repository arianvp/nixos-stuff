{
  pkgs,
  config,
  lib,
  ...
}:
let
  caFile = pkgs.concatText "ca.pub" [
    ../keys/yk-black/id_ed25519_sk_rk_ca_arian.pub
    ../keys/yk-yellow/id_ed25519_sk_rk_ca_arian.pub
  ];
in
{

  programs.ssh.extraConfig = ''
    AddKeysToAgent yes
    # CertificateFile ${../keys/yk-black/id_ed25519_sk_rk_arian-cert.pub}
    # CertificateFile ${../keys/yk-yellow/id_ed25519_sk_rk_arian-cert.pub}
    # run ssh-keygen -K to download
    # IdentityFile ~/.ssh/id_ed25519_sk_rk_arian
  '';

  # Configure SSH askpass for GNOME
  programs.ssh.enableAskPassword = lib.mkIf config.services.desktopManager.gnome.enable true;
  programs.ssh.askPassword = lib.mkIf config.services.desktopManager.gnome.enable "${pkgs.gnome-ssh-askpass4}/bin/gnome-ssh-askpass4";

  security.pam.ussh = {
    enable = true;
    inherit caFile;
    authorizedPrincipalsFile = "/etc/ssh/authorized_principals.d/root";
  };

  # disable the shit from GNOME
  services.gnome.gcr-ssh-agent.enable = false;
  programs.ssh.startAgent = true;

  environment.systemPackages = [ pkgs.opkssh ];

}
