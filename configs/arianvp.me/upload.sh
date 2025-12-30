#!/bin/sh

nixos-rebuild build-image --flake .#arianvp-me --image-variant digital-ocean
