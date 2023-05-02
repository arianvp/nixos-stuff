#!/usr/bin/env bash
set -euo pipefail

systemd-repart --definition ./repart.d --empty=force --dry-run=no $1
mount /dev/disk/by-label/root /mnt
mount /dev/disk/by-partlabel/esp /mnt/boot
nixos-install --flake github:arianvp/nixos-stuff


