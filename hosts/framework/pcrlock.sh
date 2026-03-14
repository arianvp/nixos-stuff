#!/usr/bin/env bash
set -euo pipefail

set -x

systemd_boot_dir=/var/lib/pcrlock.d/630-systemd-boot.pcrlock.d
kernel_dir=/var/lib/pcrlock.d/680-kernel.pcrlock.d
initrd_dir=/var/lib/pcrlock.d/720-kernel-initrd.pcrlock.d
mkdir -p "$systemd_boot_dir" "$kernel_dir"  "$initrd_dir"
for v in /nix/var/nix/profiles/system-*-link; do
	dir="$systemd_boot_dir"
	systemd=$(readlink "$v/systemd")
	storename=$(basename "$systemd")
	file="$dir/$storename.pcrlock"
	[ ! -e "$file" ] && "$systemd/lib/systemd/systemd-pcrlock" lock-pe "$systemd/lib/systemd/boot/efi/systemd-bootx64.efi" --pcrlock "$file"


  # Das is also fucked. We're not signing the kernel. We're signing des'UKI 
	# dir="$kernel_dir"
	# kernel=$(readlink "$v/kernel")
	# storename=$(basename "$(dirname "$kernel")")
	# file="$dir/$storename.pcrlock"
	# [ ! -e "$file" ] && "$systemd/lib/systemd/systemd-pcrlock" lock-pe "$kernel" --pcrlock "$file"


  # PCR9 is fucked. initrd is "generated" from stub and contains the contents of the pcrlock policy which is a credential that is appended
  # to the cpio archive by sd-stub
	# dir="$initrd_dir"
	# initrd=$(readlink "$v/initrd")
	# storename=$(basename "$(dirname "$initrd")")
	# file="$dir/$storename.pcrlock"
	# [ ! -e "$file" ] && "$systemd/lib/systemd/systemd-pcrlock" lock-kernel-initrd "$initrd" --pcrlock "$file"
  
  # TODO: UKI

done
