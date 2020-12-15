{ lib, pkgs, config, ...}:
{
  imports = [
    ../../modules/digitalocean/config.nix
    ../../modules/containers-v2.nix
    ./network.nix
    ./bitwarden.nix
    ./monitoring.nix
  ];

  system.stateVersion = "19.03";

  # needed for networkd to function. obscure
  time.timeZone = "Europe/Amsterdam";

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

  services.systemd-nspawn.machines = {
    "test1".config = {...}: {
      services.nginx.enable = true;
    };
    "test2".config = {...}: {
      services.nginx.enable = true;
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts = {
      "arianvp.me" = {
        forceSSL = true;
        enableACME = true;
        locations."/".root = pkgs.arianvp-website;
        # locations."/chrome-reproducer".index = "${../../chrome-reproducer.html}";
      };
      /*"techstock.photos" = {
        forceSSL = true;
        enableACME = true;
        locations."/reproducer".root = pkgs.writeTextDir "index.html"
        ''
          ${../../chrome-reproducer.html}
          '';
      };*/
    };
  };

  # Needed to accept terms
  security.acme.email = "arian.vanputten@gmail.com";
  security.acme.acceptTerms = true;


  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIDXJypxL7B7Pl4WS4Suv654AguJMhYjKBPhTQNLRsBOgAAAABHNzaDo= ssh:"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAICUTTzP5D0bLXRqGkw3ujx9ihqAYVC/Tz8RBz06FCeh0AAAABHNzaDo= ssh:"
  ];

}
