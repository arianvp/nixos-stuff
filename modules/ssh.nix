{ pkgs, ... }:

let
  caKeys = pkgs.concatText "ca.pub" [
    ../keys/yk-black/id_ed25519_sk_rk_ca_arian.pub
    ../keys/yk-yellow/id_ed25519_sk_rk_ca_arian.pub
  ];
in
{

  imports = [ ./ssh-authorized-principals.nix ];

  programs.ssh.extraConfig = ''
    CertificateFile ${../keys/yk-black/id_ed25519_sk_rk_arian-cert.pub}
    CertificateFile ${../keys/yk-yellow/id_ed25519_sk_rk_arian-cert.pub}
    # run ssh-keygen -K to download
    IdentityFile ~/.ssh/id_ed25519_sk_rk_arian
  '';

  services.openssh.enable = true;

  services.openssh.settings = {
    PasswordAuthentication = false;
    TrustedUserCAKeys = "${caKeys}";
    RevokedKeys = "${../keys/revoked_keys}";
  };

  services.openssh.authorizedPrincipals = {
    root = [ "arian" "flokli" ];
    arian = [ "arian" ];
    flokli = [ "flokli" ];
  };
}
