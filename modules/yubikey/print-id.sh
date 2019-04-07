#!/bin/sh
ssh-keygen -D "$(nix-build '<nixpkgs>' --no-out-link -A yubico-piv-tool)/lib/libykcs11.so" -e
