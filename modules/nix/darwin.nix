{ pkgs, lib, ... }:
{
  imports = [ ./common.nix ];

  nix.settings.allowed-users = [ "@staff" ]; # any real user on macOS
  nix.settings.trusted-users = [ "@admin" ];

  nix.gc.interval = [
    {
      Hour = 13;
      Minute = 0;
    }
  ];

  # the VM can not reach tailscale; so disable substitutes
  nix.settings.builders-use-substitutes = lib.mkForce false;

  nix.linux-builder = {
    enable = true;
    package = pkgs.darwin.linux-builder-vz;
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];

    ephemeral = true;
    maxJobs = 4;
    # "kvm" comes from ./m4.nix on hosts whose chip can do nested virtualisation.
    supportedFeatures = [
      "benchmark"
      "big-parallel"
      "nixos-test"
    ];

    config =
      { pkgs, config, ... }:
      {
        # nix.package = pkgs.lixPackageSets.latest.lix;

        /*
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
        */

        virtualisation = {
          darwin-builder = {
            diskSize = 40 * 1024; # MiB
            memorySize = 8 * 1024; # MiB
          };
          cores = 8;
        };
      };
  };
}
