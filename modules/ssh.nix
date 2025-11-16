{ pkgs, ... }:

let
  caKeys = pkgs.concatText "ca.pub" [
    ../keys/yk-black/id_ed25519_sk_rk_ca_arian.pub
    ../keys/yk-yellow/id_ed25519_sk_rk_ca_arian.pub
  ];
in
{
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.TrustedUserCAKeys = "${caKeys}";
}
