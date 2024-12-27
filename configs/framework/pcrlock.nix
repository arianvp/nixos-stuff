{ pkgs, config, ... }:

let bootLoaderLock = pkgs.runCommand "240-boot-loader.pcrlock" { } ''
  ${config.systemd.package}/lib/systemd-pcrlock lock-pe 
'';

in {


  boot.initrd.systemd.additionalUpstreamUnits =
    [ "systemd-pcrphase-initrd.service" ];

  boot.initrd.systemd.targets.initrd.wants =
    [ "systemd-pcrphase-initrd.service" ];

  boot.initrd.systemd.tpm2.enable = true;
  boot.initrd.systemd.storePaths =
    [ "${config.boot.initrd.systemd.package}/lib/systemd/systemd-pcrextend" ];

  systemd.additionalUpstreamSystemUnits = [
    "systemd-pcrextend@.service"
    "systemd-pcrextend.socket"
    "systemd-pcrfs-root.service"
    "systemd-pcrfs@.service"
    "systemd-pcrmachine.service"
    "systemd-pcrphase.service"
    "systemd-pcrphase-sysinit.service"

    "systemd-pcrlock-file-system.service"
    "systemd-pcrlock-firmware-code.service"
    "systemd-pcrlock-firmware-config.service"
    "systemd-pcrlock-machine-id.service"
    "systemd-pcrlock-make-policy.service"
    "systemd-pcrlock-secureboot-authority.service"
    "systemd-pcrlock-secureboot-policy.service"
    # "systemd-pcrlock@.service"
    # "systemd-pcrlock.socket"
  ];
  systemd.targets.sysinit.wants = [
    "systemd-pcrlock-file-system.service"
    "systemd-pcrlock-firmware-code.service"
    "systemd-pcrlock-firmware-config.service"
    "systemd-pcrlock-machine-id.service"
    "systemd-pcrlock-make-policy.service"
    "systemd-pcrlock-secureboot-authority.service"
    "systemd-pcrlock-secureboot-policy.service"
  ];
  environment.etc."pcrlock.d".source =
    "${config.systemd.package}/lib/pcrlock.d";

}
