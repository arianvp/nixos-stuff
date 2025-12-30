{ pkgs, ... }:
let
  caFile = pkgs.concatText "ca.pub" [
    ../keys/yk-black/id_ed25519_sk_rk_ca_arian.pub
    ../keys/yk-yellow/id_ed25519_sk_rk_ca_arian.pub
  ];

  principals.flokli = [
    "flokli"
    "floklink@gmail.com"
  ];
  principals.arian = [
    "arian"
    "arian.vanputten@gmail.com"
  ];
in
{
  imports = [ ./ssh-authorized-principals.nix ];
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      TrustedUserCAKeys = "${caFile}";
      RevokedKeys = "${../keys/revoked_keys}";
    };
    authorizedPrincipals = {
      root = principals.arian ++ principals.flokli;
      arian = principals.arian;
      flokli = principals.flokli;
    };
  };
  services.opkssh = {
    enable = true;
    authorizations = [
      {
        user = "arian";
        principal = "arian.vanputten@gmail.com";
        issuer = "https://accounts.google.com";
      }
      {
        user = "root";
        principal = "arian.vanputten@gmail.com";
        issuer = "https://accounts.google.com";
      }
      {
        user = "flokli";
        principal = "floklink@gmail.com";
        issuer = "https://accounts.google.com";
      }
      {
        user = "root";
        principal = "floklink@gmail.com";
        issuer = "https://accounts.google.com";
      }
    ];
  };
  systemd.dnssd.services.ssh = {
    name = "%H";
    type = "_ssh._tcp";
    port = 22;
  };
}
