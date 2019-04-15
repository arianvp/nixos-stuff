#!/bin/sh
set -e

SSHOPTS=
tmpDir=$(mktemp -t -d nixos-rebuild.XXXXXX)
SSHOPTS="$NIX_SSHOPTS -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-%n -o ControlPersist=60"

cleanup() {
    for ctrl in "$tmpDir"/ssh-*; do
        ssh -o ControlPath="$ctrl" -O exit dummyhost 2>/dev/null || true
    done
    rm -rf "$tmpDir"
}
trap cleanup EXIT


target="arianvp-me"
targetHost="arianvp.me"
profile=/nix/var/nix/profiles/system
echo "Building $target"
result=$(nix-build  --no-out-link -A "${target}.toplevel" --show-trace)
# nix sign-paths --recursive --key-file "${keyFile}" "${result}"
echo "Copying $target"
NIX_SSHOPTS=$SSHOPTS nix copy --no-check-sigs --to "ssh://root@$targetHost" "$result"
echo "Setting profile for $target"
ssh $SSHOPTS "root@$targetHost" nix-env -p "$profile" --set "$result"

echo "Switching to $target"
ssh $SSHOPTS "root@$targetHost" "$result/bin/switch-to-configuration" switch



