{ pkgs, ... }:

let
  caKeys = pkgs.concatText "ca.pub" [
    ../keys/yk-black/id_ed25519_sk_rk_ca_arian.pub
    ../keys/yk-yellow/id_ed25519_sk_rk_ca_arian.pub
  ];
in
{
  services.openssh.settings = {
    PasswordAuthentication = false;
    TrustedUserCAKeys = "${caKeys}";
    AuthorizedPrincipalsFile = "/etc/ssh/authorized_principals.d/%u";
    RevokedKeys = "${../keys/revoked_keys}";
  };


  environment.etc."ssh/authorized_principals.d/root" = pkgs.writeText "root" ''
    arian
    flokli
  '';

}
