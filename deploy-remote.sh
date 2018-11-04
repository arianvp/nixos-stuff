#!/bin/sh
set -e

# tmpDir=$(mktemp -t -d nixos-rebuild.XXXXXX)
# SSHOPTS="$NIX_SSHOPTS -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-%n -o ControlPersist=60"

# cleanup() {
#     for ctrl in "$tmpDir"/ssh-*; do
#         ssh -o ControlPath="$ctrl" -O exit dummyhost 2>/dev/null || true
#     done
#     rm -rf "$tmpDir"
# }
# trap cleanup EXIT


target="arianvp-me"
targetHost="arianvp.me"
profile=/nix/var/nix/profiles/system
result=$(nix-build ./nixpkgs.nix --no-out-link -A "deployments.${target}.toplevel")
# nix sign-paths --recursive --key-file "${keyFile}" "${result}"
nix copy --no-check-sigs --to "ssh://root@$targetHost" "$result"
ssh "root@$targetHost" nix-env -p "$profile" --set "$result"
ssh "root@$targetHost" "$result/bin/switch-to-configuration" switch


