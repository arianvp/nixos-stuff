#!/usr/bin/env bash
set -euo pipefail

systemd-repart --definition ./repart.d --dry-run=no $1
udevadm trigger && udevadm settle
mount /dev/disk/by-partlabel/root-arm64 /mnt
mount /dev/disk/by-partlabel/esp /mnt/boot
nixos-install --no-channel-copy --flake .#altra


