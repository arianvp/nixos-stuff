#!/bin/sh

nix build --file .  --extra-substituters "auto?trusted=1" --store /mnt deployments.t490s.toplevel


nixos-install --no-channel-copy --system ./result
