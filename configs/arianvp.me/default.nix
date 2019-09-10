{ lib, pkgs, ...}:
{
  imports = [ 
    ../../modules/digitalocean/config.nix 
  ];

  system.stateVersion = "19.03";

  # Weechat
  services.weechat.enable = true;
  networking.firewall.allowedTCPPorts = [ 
    80   # http
    443  # https
    4443 # weechat relay
  ];

  programs.screen.screenrc = ''
    multiuser on
    acladd normal_user
  '';

  services.nginx = {
    enable = true;
    virtualHosts = {
      "arianvp.me" = {
        forceSSL = true;
        enableACME = true;
        locations."/".root = pkgs.arianvp-website;
      };
      "techstock.photos" = {
        forceSSL = true;
        enableACME = true;
        locations."/".root = pkgs.writeTextDir "index.html"
          ''
          <!doctype html>
          <h1> Tech Stock Photos </h1>
          <h2> Royalty Free Non-crappy tech stock photos will come here </h2>
          '';
      };
    };
  };

  # Allow weechat to access the cert
  security.acme.certs."arianvp.me" = {
    group = "weechat";
    allowKeysForGroup = true;
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [
    (pkgs.fetchurl {
      url = "https://github.com/arianvp.keys";
      sha256 = "0v6hsr6xcpw7b5cdlb312jm4jy1dahqll8v8ppgcbrfgpxp5gmm6";
    })
  ];

}
