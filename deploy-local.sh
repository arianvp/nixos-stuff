#!/bin/sh
set -e

target="ryzen"
result=$(nix-build ./nixpkgs.nix --no-out-link -A "deployments.${target}.toplevel")
sudo "${result}/bin/switch-to-configuration" switch


