#!/usr/bin/env bash

set -euo pipefail
toplevel=$1
bootspec=$toplevel/boot.json
kernel=$(jq '.["org.nixos.bootspec.v1"].kernel' "$bootspec")
version=$(basename "$(dirname "$kernel")")
initrd=$(jq '.["org.nixos.bootspec.v1"].initrd' "$bootspec")


KERNEL_INSTALL_LAYOUT=

# install.conf
# Currently, the following keys are supported: MACHINE_ID=, BOOT_ROOT=, layout=, initrd_generator=, uki_generator=. See the Environment variables section above for details.

# will install
echo kernel-install add "$version" "$kernel" "$initrd"

# now if we are UKI we need to pack the cmdline as a UKI addon


