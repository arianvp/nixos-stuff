{ config, pkgs, ... }:
  {
    imports = [
      ./hardware-configuration.nix
      ./irc.nix
      ../../modules/gitlab-runner.nix
      ./monitoring.nix
      ./minecraft.nix
    ];
    boot.loader.grub = {
      enable = true;
      version = 2;
      device = "/dev/vda";
    };
    services.openssh = {
      enable = true;
      passwordAuthentication = false;
    };
    # Experimental, lets see how it goes
    networking.useNetworkd = true;
    networking.firewall.allowedTCPPorts = [
      22
      80
      443
      4443
    ];
    services.gitlab-runner2.enable = true;
    services.gitlab-runner2.registrationConfigFile = "/var/lib/gitlab-runner/secret";
    users.users.root.openssh.authorizedKeys.keyFiles = [
      (pkgs.fetchurl {
        url = "https://github.com/arianvp.keys";
        sha256 = "0v6hsr6xcpw7b5cdlb312jm4jy1dahqll8v8ppgcbrfgpxp5gmm6";
      })
    ];
    services.nginx = {
      enable = true;
      virtualHosts = {
        "arianvp.me" = {
          forceSSL = true;
          enableACME = true;
          locations."/".root = "/var/www/arianvp.me";
        };
      };
    };
    security.acme.certs."arianvp.me" = {
      group = "weechat";
      allowKeysForGroup = true;
    };
    system.stateVersion = "18.03";
  }
