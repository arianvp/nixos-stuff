{ config, pkgs, ... }:
  {
    nixpkgs.config.allowUnfree = true;
    nixpkgs.overlays = [
      (self:
        super:
          {
            minecraft-server = super.minecraft-server.overrideAttrs (_:
              rec {
                name = "minecraft-server-${version}";
                version = "1.13.1";
                src = super.fetchurl {
                  url = "https://launcher.mojang.com/v1/objects/fe123682e9cb30031eae351764f653500b7396c9/server.jar";
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
      timerConfig.OnCalendar = "*-*-* 4:00:00";
      wantedBy = [ "timers.target" ];
    };
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
  }
