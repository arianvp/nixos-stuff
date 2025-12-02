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


  # Setting mode forces NixOS to copy the file instead of symlinking to /nix/store.
  # Without this, sshd rejects the file with:
  # "Ignored authorized principals: bad ownership or modes for directory /nix/store"
  # because /nix/store is group-writable (1775) which violates sshd's strict path checks.
  environment.etc."ssh/authorized_principals.d/root" = {
    text = ''
      arian
      flokli
    '';
    mode = "0644";
  };

  environment.etc."ssh/authorized_principals.d/arian" = {
    text = ''
      arian
    '';
    mode = "0644";
  };

  environment.etc."ssh/authorized_principals.d/flokli" = {
    text = ''
      flokli
    '';
    mode = "0644";
  };
}
