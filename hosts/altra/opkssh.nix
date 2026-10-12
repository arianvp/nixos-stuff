{ config, lib, ... }:
let
  issuer = "https://${config.services.nixbot.domain}";
in
{
  # Lets the deploy-altra effect in ../../herculesCI.nix log in as root with a
  # nixbot-issued ID token, see ../../overlays/opkssh-nixbot.patch.
  services.opkssh = {
    enable = true;
    providers.nixbot = {
      inherit issuer;
      clientId = "OPKSSH-NIXBOT:altra";
      lifetime = "oidc";
    };
    # Only nixbot; the Google logins from ../../modules/sshd.nix stay off here.
    authorizations = lib.mkForce [
      {
        user = "root";
        principal = "repo:github:arianvp/nixos-stuff:ref:refs/heads/master";
        inherit issuer;
      }
    ];
  };
}
