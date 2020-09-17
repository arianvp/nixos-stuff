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

  # Allow weechat to access the cert
  security.acme.certs."arianvp.me" = {
    group = "weechat";
    allowKeysForGroup = true;
  };

  users.users.root.openssh.authorizedKeys.keyFiles = [
    (pkgs.fetchurl {
      url = "https://github.com/arianvp.keys";
      sha256 = "0ypavfx99qmf4a0jb05l0bbqvmq7zkvgl3r8zhdx46ryk62gjbwh";
    })
  ];

}
