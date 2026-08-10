{ pkgs, lib, ... }:
{
  nix.enable = true;
  nix.package = pkgs.lixPackageSets.latest.lix;
  nix.settings.trusted-users = [ "arian" ];
  nix.settings.allowed-users = [ "arian" ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # the VM can not reach tailscale; so disable substitutes
  nix.settings.builders-use-substitutes = lib.mkForce false;

  nix.linux-builder = {
    enable = true;
    package = pkgs.darwin.linux-builder-vz; # new
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];

    ephemeral = true;
    maxJobs = 4;
    supportedFeatures = [
      # "kvm" # requires nestedVirtualization below (OPTIONAL)
      "benchmark"
      "big-parallel"
      "nixos-test"
    ];

    config =
      { pkgs, config, ... }:
      {
        nix.package = pkgs.lixPackageSets.latest.lix;

        systemd.services.rosettad =
          let
            cfg = config.virtualisation.rosetta;
          in
          {
            wantedBy = [ "multi-user.target" ];
            unitConfig = {
              ConditionPathExists = "${cfg.mountPoint}/rosettad";
            };
            serviceConfig = {
              CacheDirectory = "rosettad";
              RuntimeDirectory = "rosettad"; # Makes sure the directory exists before starting
              ExecStart = "${cfg.mountPoint}/rosettad daemon $CACHE_DIRECTORY";
              Restart = "always";
            };
          };

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
}
