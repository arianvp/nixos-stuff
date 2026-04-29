#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt-get >/dev/null 2>&1; then
	echo "apt-get not found; this script targets Debian/Ubuntu" >&2
	exit 1
fi

sudo apt-get update
sudo apt-get install -y nix-bin nix-setup-systemd

sudo systemctl enable --now nix-daemon.socket

if ! getent group nix-users | grep -qw "$USER"; then
	sudo usermod -aG nix-users "$USER"
	echo "Added $USER to nix-users; log out and back in for it to take effect."
fi

sudo install -d -m 0755 /etc/nix
if [ ! -e /etc/nix/nix.conf ] || ! grep -q '^experimental-features' /etc/nix/nix.conf; then
	echo 'experimental-features = nix-command flakes' | sudo tee -a /etc/nix/nix.conf >/dev/null
fi

echo "Nix installed via apt. Open a new shell to use it."
