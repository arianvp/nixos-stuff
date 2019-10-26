#!/bin/sh

# Some notes for me how to sign builds

# nix-store --generate-binary-cache-key arian key key.pub
nix-build -A deployments.t490s --option secret-key-files "$(realpath key)"
nix verify --sigs-needed 1 ./result --option trusted-public-keys "$(cat key.pub)"
