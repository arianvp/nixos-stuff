{ pkgs, ... }:
{

  nixpkgs.hostPlatform = "aarch64-darwin";

  # Makes nix-darwin add `/etc/profiles/per-user/$USER/bin` and
  # `/run/current-system/sw/bin` to PATH, so home-manager-installed
  # packages (via `home.packages`) are actually on PATH.
  programs.zsh.enable = true;

  system.primaryUser = "arian";

  users.users.arian.home = "/Users/arian";

  nix.enable = true;
  nix.package = pkgs.lixPackageSets.latest.lix;
  nix.settings.trusted-users = [ "arian" ];
  nix.settings.allowed-users = [ "arian" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.linux-builder = {
    enable = true;
    # package = pkgs.darwin.linux-builder-vz; # new
    systems = [
      "aarch64-linux"
      # "x86_64-linux"
    ];

    ephemeral = true;
    maxJobs = 4;
    supportedFeatures = [
      # "kvm" # requires nestedVirtualization below (OPTIONAL)
      "benchmark"
      "big-parallel"
      "nixos-test"
    ];

    config = { pkgs, ... }: {
      # nix.package = pkgs.lixPackageSets.latest.lix;
      virtualisation = {
        darwin-builder = {
          diskSize = 40 * 1024; # MiB
          memorySize = 8 * 1024; # MiB
        };
        cores = 8;

        # OPTIONAL:
        # Real /dev/kvm in the guest, for running NixOS VM tests on the
        # builder. Needs macOS 15+ and an M3 or newer chip.
        # vz.nestedVirtualization = true; # new
      };
    };
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
