#!/usr/bin/env bash

set -euo pipefail
set -x

STORE=${STORE:-/var/lib/nixos/boot}
PROFILE_NAME=${PROFILE_NAME:-entries}
BOOT=${BOOT:-/boot}
INSTANCES_MAX=${INSTANCES_MAX:-}

substituter="auto?trusted=1"
state="$STORE/nix/var/nix"
profiles="$state/profiles"
profile="$profiles/$PROFILE_NAME"

# Set up gcroot for boot entries
nix-env --extra-substituters "$substituters" --store "$STORE" --profile "$profile" --set "$ENTRY"

# garbage collect old kernels and initrds
nix-env --delete-generations "+${INSTANCES_MAX}" --profile "$profile" --store "$STORE"
nix-store --gc --store "$STORE"

# Copy required paths from staging area to boot partition
mkdir -p "$BOOT/nix"
rsync --recursive --delete --progress "$STORE/nix/store" "$BOOT/nix"




