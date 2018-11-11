#!/bin/sh
set -e
set -x

target="ryzen"
profile=/nix/var/nix/profiles/system
result=$(nix-build ./nixpkgs.nix --no-out-link -A "deployments.${target}.toplevel")
sudo nix-env -p "$profile" --set "$result"
sudo "${result}/bin/switch-to-configuration" switch
./setup-user-env.sh


