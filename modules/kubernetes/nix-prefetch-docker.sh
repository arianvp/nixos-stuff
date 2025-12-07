#!/bin/sh

nix run nixpkgs#nix-prefetch-docker -- --arch arm64 --os linux registry.k8s.io/pause 3.10.1 > images/pause.nix
nix run nixpkgs#nix-prefetch-docker -- --arch arm64 --os linux registry.k8s.io/e2e-test-images/nginx 1.14-2 > images/e2e-test-images-nginx.nix
nix run nixpkgs#nix-prefetch-docker -- --arch arm64 --os linux registry.k8s.io/e2e-test-images/busybox 1.29-2> images/busybox.nix
