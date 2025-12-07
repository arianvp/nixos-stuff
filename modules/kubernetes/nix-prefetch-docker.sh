#!/bin/sh
nix run nixpkgs#nix-prefetch-docker -- --image-name registry.k8s.io/pause --image-tag 3.10.1  --arch arm64 --os linux > images/pause.nix
