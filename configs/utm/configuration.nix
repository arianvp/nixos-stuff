{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    # ../../modules/monitoring.nix
    ./soft-reboot.nix
    ../../modules/repro.nix
    ../../modules/spire/agent.nix
    ../../modules/spire/server.nix
  ];

  security.auditd.enable = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  # Virtualization.framework EFI driver doesnt' seem to support graphics anyway
  boot.consoleLogLevel = 3;
  boot.loader.timeout = 20;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.compressor = "cat";
  boot.initrd.systemd.enable = false;
  # system.etc.overlay.enable = true;
  virtualisation.rosetta.enable = true;
  # virtualisation.podman.enable = true;
  services.getty.autologinUser = "arian";
  # networking.hostName = "nixos"; # Define your hostname.
  # Pick only one of the below networking options.
  # Set your time zone.
  # See https://github.com/NixOS/nixpkgs/issues/311125
  # time.timeZone = "Europe/Amsterdam";
  networking.firewall.enable = false;
  # programs.nix-ld.enable = true;
  systemd.targets.network-online.wantedBy = lib.mkForce [ ];
  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    packages = [
      pkgs.vim
      pkgs.git
      pkgs.direnv
      # pkgs.bpftrace
    ];
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMaGVuvE+aNyuAu0E9m5scVhmnVgAutNqridbMnc261cHQwecih720LCqDwTgrI3zbMwixBuU422AK0N81DyekQ= arian@Arians-MacBook-Pro.local"
    ];
  };

  services.openssh.enable = true;
  services.openssh.startWhenNeeded = true;

  # Systemd conveniently ships with this service that will check if no services failed
  # https://www.freedesktop.org/software/systemd/man/systemd-boot-check-no-failures.service.html
  # This is part of https://systemd.io/AUTOMATIC_BOOT_ASSESSMENT/
  systemd.additionalUpstreamSystemUnits = [ "systemd-boot-check-no-failures.service" ];

  systemd.oomd.enableSystemSlice = true;

  swapDevices = [
    {
      device = "/var/lib/swap";
      size = 4 * 1024;
    }
  ];

  # TODO Fix upstream
  # systemd.targets.boot-complete.requires = [ "systemd-boot-check-no-failures.service" ];

  boot.swraid.enable = true;
  programs.bcc.enable = true;

  environment.systemPackages = [ pkgs.direnv ];
  programs.zsh.enable = true;
  programs.bash.interactiveShellInit = ''
    eval "$(direnv hook bash)"
  '';
  nix.settings.trusted-users = [ "@wheel" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "fetch-closure"
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.05"; # Did you read the comment?A

  spire.agent = {
    enable = true;
    trustDomain = "arianvp.me";
    trustBundleUrl = "https://spire.arianvp.me/bundle.json";
    serverAddress = "127.0.0.1";
    config = ''
      plugins {
        KeyManager "memory" {
          plugin_data {
          }
        }
        NodeAttestor "http_challenge" {
          plugin_data {
          }
        }
        WorkloadAttestor "systemd" {
          plugin_data {
          }
        }
        WorkloadAttestor "unix" {
          plugin_data {
          }
        }
      }
    '';
  };
  spire.server = {
    enable = true;
    trustDomain = "arianvp.me";
    config = ''
      server {
        federation {
          bundle_endpoint {
            address = "0.0.0.0"
            port = 443
            profile "https_web" {
              acme {
                domain_name = "spire.arianvp.me"
                email = "spire@arianvp.me"
                tos_accepted = true
              }
            }
          }
        }
      }
      plugins {
        KeyManager "memory" {
          plugin_data {
          }
        }
        DataStore "sql" {
          plugin_data {
            database_type = "sqlite3"
            connection_string = "$STATE_DIRECTORY/datastore.sqlite3"
          }
        }
        NodeAttestor "http_challenge" {
          plugin_data {
          }
        }
        NodeAttestor "join_token" {
          plugin_data {
          }
        }
      }
    '';
  };

}
