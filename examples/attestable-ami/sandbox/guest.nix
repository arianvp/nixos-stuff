# A Nitro Sandbox guest, built like the AMI from ../modules and laid out like
# AWS's own sandbox guest. A sandbox boots a kernel, an initrd and a command
# line, all three measured, and gets the system from a read-only drive: the
# store of ../modules/verity-store.nix, whose root hash is on the command
# line. The workload greets the parent instance over vsock and powers the
# sandbox off.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 5000;
  # Without the helper scripts, which are written in bash.
  socat = pkgs.socat.overrideAttrs (previousAttrs: {
    postInstall = previousAttrs.postInstall or "" + ''
      rm $out/bin/*.sh
    '';
  });
  inherit (config.image.repart.verityStore) partitionIds;
  storeVerityLabel = config.image.repart.partitions.${partitionIds.store-verity}.repartConfig.Label;
in
{
  imports = [
    ../modules/appliance.nix
    ../modules/nitro-sandbox-guest-kernel.nix
    ../modules/verity-store.nix
  ];

  system.image.id = "nitro-sandbox";

  environment.etc.greeting.text = ''
    Hello from a Nitro Sandbox running NixOS ${config.system.nixos.release} on Linux ${config.boot.kernelPackages.kernel.version}
  '';

  systemd.services.hello = {
    description = "Greet the parent instance";
    wantedBy = [ "multi-user.target" ];
    unitConfig.SuccessAction = "poweroff-force";
    serviceConfig = {
      Type = "oneshot";
      # The parent is always CID 2.
      ExecStart = "${lib.getExe socat} -u OPEN:/etc/greeting VSOCK-CONNECT:2:${toString port}";
    };
  };

  # What it takes to launch the sandbox: the kernel, the initrd, the drive
  # with the store (without the ESP that repart's verity store layout has for
  # booting from disk), and a command line that pins the drive's root hash.
  system.build.nitro-sandbox = {
    inherit port;
    kernel = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
    initrd = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
    drive = "${config.system.build.intermediateImage}/${config.image.baseName}.raw";
    # The init it names is on the drive, so the parent needn't have it.
    cmdline =
      pkgs.runCommand "nitro-sandbox-cmdline"
        {
          nativeBuildInputs = [ pkgs.buildPackages.jq ];
          __structuredAttrs = true;
          unsafeDiscardReferences.out = true;
        }
        ''
          usrhash=$(jq -r '.[] | select(.label == "${storeVerityLabel}") | .roothash' \
            ${config.system.build.intermediateImage}/repart-output.json)
          echo -n "init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams} usrhash=$usrhash" > $out
        '';
  };

  system.stateVersion = "26.05";
}
