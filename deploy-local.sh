#!/bin/sh
set -e
set -x
sudo nix-channel --update
target="$1"
profile=/nix/var/nix/profiles/system
result=$(nix-build ./nixpkgs.nix --no-out-link -A "deployments.${target}.toplevel" --show-trace)
sudo nix-env -p "$profile" --set "$result"
sudo "${result}/bin/switch-to-configuration" switch
./setup-user-env.sh


