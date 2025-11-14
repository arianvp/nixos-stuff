# Secure Boot

We use lanzaboote for secure boot.


We use `systemd-pcrlock` for unlocking the disk.

Support for measured boot is still an open issue https://github.com/nix-community/lanzaboote/issues/348


We lock against the firmware code (`systemd-pcrlock-firmware-code.service` is
enabled). Note that before updating firmware, you should run `systemd-pcrlock
unlock-firmware-code` followed by `systemd-pcrlock make-policy` to relax the
policy temporarily. On next boot the firmware code is immediately locked again.

We do *not* use `lock-firmware-config`.  The Insyde firmware seems to make inpredictible
measurements to `EFI_HANDOFF_TABLES` (Which contains the SMBIOS). This is not spec-compliant
but we can not change this.

We enable both `lock-secureboot-policy` and `lock-secureboot-authority`. These are enabled during
boot automatically.

Keys are stored in `/var/lib/sbctl` and were generated with `sudo sbctl create-keys`




