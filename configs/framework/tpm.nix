{

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
}
