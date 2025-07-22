{ inputs, pkgs, ... }:
{
  imports = [
    ./dnssd.nix
    ./monitoring.nix
  ];

  services.openssh.settings.PasswordAuthentication = false;

  nix.settings.substituters = [
    "https://nixos.tvix.store?priority=39"
    "https://cache.nixos.org?priority=40"
  ];

  nix.settings.trusted-users = [
    "@wheel"
    "@nix-trusted-users"
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "fetch-closure"
  ];

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "@wheel" ];

    # Until we have a proper SSH-CA this is what we do instead
    openssh.authorizedKeys.keyFiles = [
      (pkgs.fetchurl {
        url = "https://github.com/arianvp.keys";
        sha256 = "sha256-HyJKxLYTQC4ZG9Xh91bCUVzkC1TBzvFkZR1XqT7aD7o=";
      })
    ];
  };

  systemd.services.auto-upgrade = {
    description = "Auto upgrade NixOS";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellApplication {
        name = "auto-upgrade";
        text = ''
        '';
      }
    };
  };

  /*
    system.autoUpgrade = {
    enable = true;
    flake = "/etc/nixos";
    flags = [
      "--update-input"
      "unstable"
      "--commit-lock-file"
    ];
    };
  */
}
