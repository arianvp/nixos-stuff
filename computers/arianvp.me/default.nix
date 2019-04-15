{ pkgs, ...}:
{
  imports = [ 
    ../../modules/digitalocean/config.nix 
  ];

  system.stateVersion = "19.03";

  # Weechat
  services.weechat.enable = true;
  programs.screen.screenrc = ''
    multiuser on
    acladd normal_user
  '';

  services.nginx = {
    enable = true;
    virtualHosts."arianvp.me" = {
      forceSSL = true;
      enableACME = true;
      locations."/".root = pkgs.arianvp-website;
    };
  };

  # Allow weechat to access the cert
  security.acme.certs."arianvp.me" = {
    group = "weechat";
    allowKeysForGroup = true;
  };

    
}
