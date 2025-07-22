{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
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

  systemd.timers.auto-upgrade = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "daily";
  };

  systemd.services.auto-upgrade = lib.mkIf (lib.hasAttr "rev" inputs.self) {
    description = "Auto upgrade NixOS";
    serviceConfig = {
      Type = "oneshot";
      User = "arian";
      StateDirectory = "auto-upgrade";
      WorkingDirectory = "%S/auto-upgrade";
      ExecStart =
        let
          checkout-build-and-commit = pkgs.writeShellApplication {
            name = "checkout-build-and-commit";
            runtimeInputs = [
              pkgs.nix
              pkgs.git
              pkgs.openssh
            ];
            text = ''
              git clone git@github.com:arianvp/nixos-stuff.git "$STATE_DIRECTORY" || true
              git fetch origin
              git checkout -B "flake-update-${config.system.name}" "${inputs.self.rev}"
              nix build --update-input unstable --commit-lock-file --profile /nix/var/nix/profiles/system
            '';
          };
          upgrade = pkgs.writeShellApplication {
            name = "upgrade";
            text = ''
              /nix/var/nix/profiles/system/system/bin/switch-to-configuration boot
            '';
          };
          push = pkgs.writeShellApplication {
            name = "push";
            runtimeInputs = [ pkgs.git ];
            text = ''
              git push -f origin "flake-update-${config.system.name}"
            '';
          };
        in
        [
          (lib.getExe checkout-build-and-commit)
          "!${(lib.getExe upgrade)}"
          "-${(lib.getExe push)}"
        ];
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
