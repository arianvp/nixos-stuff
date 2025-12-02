{ pkgs, ... }:

let
  caKeys = pkgs.concatText "ca.pub" [
    ../keys/yk-black/id_ed25519_sk_rk_ca_arian.pub
    ../keys/yk-yellow/id_ed25519_sk_rk_ca_arian.pub
  ];
in
{

  /*programs.ssh.extraConfig = ''
    CertificateFile ${../keys/yk-black/id_ed25519_sk_rk_arian-cert.pub}
    CertificateFile ${../keys/yk-yellow/id_ed25519_sk_rk_arian-cert.pub}
  '';*/
  services.openssh.settings = {
    PasswordAuthentication = false;
    TrustedUserCAKeys = "${caKeys}";
    AuthorizedPrincipalsFile = "/etc/ssh/authorized_principals.d/%u";
    RevokedKeys = "${../keys/revoked_keys}";
  };


  environment.etc."ssh/authorized_principals.d/root".text = ''
    arian
    flokli
  '';


  environment.etc."ssh/authorized_principals.d/arian".text = ''
    arian
  '';

  environment.etc."ssh/authorized_principals.d/flokli".text = ''
    flokli
  '';
}
