{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix  ./irc.nix ../../modules/gitlab-runner.nix ];
  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/vda";
  };
  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (self: super: {
      minecraft-server = super.minecraft-server.overrideAttrs (_: rec {
        name    = "minecraft-server-${version}";
        version = "1.13.1";
        src  = super.fetchurl {
          url    = "https://launcher.mojang.com/v1/objects/fe123682e9cb30031eae351764f653500b7396c9/server.jar";
          sha256 = "1lak29b7dm0w1cmzjn9gyix6qkszwg8xgb20hci2ki2ifrz099if";
        };
      });
    })
  ];


  services.minecraft-server = {
    enable = true;
    openFirewall = true;
  };

  systemd.services.minecraft-backup = {
    serviceConfig.Type = "oneshot";
    script = ''
      MCBACKUPS='${config.users.users.rightfold.home}'
      export PATH='${pkgs.gzip}/bin:${pkgs.gnutar}/bin:${pkgs.coreutils}/bin'
      tar cz -C '${config.services.minecraft-server.dataDir}' . > "$MCBACKUPS/world-$(date -Iseconds).tar.gz"
    '';
  };
  systemd.timers.minecraft-backup = {
    timerConfig.OnCalendar =  "*-*-* 4:00:00";
    wantedBy = [ "timers.target" ];
  };

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      polkit.log("action=" + subject);
      polkit.log("subject=" + subject);
      if (action.id == "org.freedesktop.systemd1.manage-units") {
        if (action.lookup("unit") == "minecraft-backup.service") {
          var verb = action.lookup("verb");
          if (verb == "start" || verb == "stop" || verb == "restart") {
            if (subject.user == "rightfold") {
              return polkit.Result.YES;
            }
          }
        }
      }
    });
  '';

  services.openssh = {
    enable = true;
    passwordAuthentication = false;
  };

  networking.firewall.allowedTCPPorts = [ 22 80 443 4443 ];


  services.gitlab-runner2.enable = true;
  services.gitlab-runner2.registrationConfigFile = "/var/lib/gitlab-runner/secret";


  users.users.root.openssh.authorizedKeys.keyFiles = [
    (pkgs.fetchurl {
      url = "https://github.com/arianvp.keys"; 
      sha256 = "0v6hsr6xcpw7b5cdlb312jm4jy1dahqll8v8ppgcbrfgpxp5gmm6";
    })
  ];

  users.users.rightfold = {
    createHome = true;
    isNormalUser = true;
    openssh.authorizedKeys.keyFiles = [
      (pkgs.fetchurl {
        url = "https://github.com/rightfold.keys"; 
        sha256 = "0q6zidm6cpqvpcbgs82v006d3i3qla9040fv65jjmyh9z4lq92m1";
      })
    ];
  };




  services.nginx = {
    enable = true;
    virtualHosts."arianvp.me" = {
      forceSSL = true;
      enableACME = true;
      locations."/".root = "/var/www/arianvp.me";
    };
  };

  # Makes sure that weechat has access to the key as well
  security.acme.certs."arianvp.me" = {
    group = "weechat";
    allowKeysForGroup = true;
  };


  system.stateVersion = "18.03"; # Did you read the comment?

}
