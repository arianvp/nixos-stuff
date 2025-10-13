#!/usr/bin/env bash

STORE=${STORE:-/var/lib/nixos/boot}
PROFILE_NAME=${PROFILE_NAME:-boot}
BOOT=${BOOT:-/boot}
INSTANCES_MAX=${INSTANCES_MAX:-}
toplevel=$1

substituter="auto?trusted=1"
state="$STORE/nix/var/nix"
profiles="$state/profiles"
profile="$profiles/$PROFILE_NAME"

nix-env \
	--extra-substituters "$subtituter" \
	--profile "$profile" \
	--store "$STORE" \
	--set "$storePath"

# garbage collect old kernels and initrds
nix-env --delete-generations "+${INSTANCES_MAX}" --profile "$profile" --store "$STORE"
nix-store --gc --store "$STORE"

# Copy required paths
# TODO: no symlinks. no permissions. Just copies and deletes. that's all that it supports
# TODO: --delete
mkdir -p "$BOOT/nix"
rsync --recursive --archive --delete --progress "$STORE/nix/store" "$BOOT/nix"




