#!/bin/sh
nixos-rebuild --target-host root@95.179.181.147 switch -I nixos-config=. --show-trace
