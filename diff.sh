#!/bin/sh
nix-diff $(nix-store --query --deriver --store ssh://root@arianvp.me $(ssh root@arianvp.me readlink /run/current-system)) $(nix-instantiate  . -A fork.deployments.arianvp-me.toplevel)
