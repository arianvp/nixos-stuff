#!/bin/sh
set -e

target="ryzen"
result=$(nix-build ./nixpkgs.nix --no-out-link -A "deployments.${target}.toplevel")
ssh "root@$targetHost" nix-env -p "$profile" --set "$result"
sudo "${result}/bin/switch-to-configuration" switch
./setup-user-env.sh


