#!/bin/sh
set -e

target="arianvp-me"
targetHost="arianvp.me"
result=$(nix-build ./nixpkgs.nix --no-out-link -A "deployments.${target}.toplevel")
# nix sign-paths --recursive --key-file "${keyFile}" "${result}"
nix copy --no-check-sigs --to "ssh://root@${targetHost}" "${result}"
ssh "root@$targetHost" "${result}/bin/switch-to-configuration switch"


