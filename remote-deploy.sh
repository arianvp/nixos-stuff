#!/usr/bin/env bash
set -e
set -x

name="$1"
installable="$2"
shift 2 || true

if [[ -z "$name" ]]; then
	echo "Usage: $0 <host> [installable] [nix build args...]" >&2
	exit 1
fi

: "${installable:=.#nixosConfigurations.\"$name\".config.system.build.toplevel}"

mkdir -p ".roots/$name"


system=$(nix build "$installable" --print-out-paths --profile ".roots/$name/new-system" "$@")

for s in current-system booted-system; do
	nix-store --realise --add-root ".roots/$name/$system" "$(ssh "$name" readlink /run/$s-system)"
done

# Rsync to remote - delete is safe because closure includes both old and new
nix-store -qR ".roots/$name"/* | rsync -av --delete --files-from=- / "$name":/

# Switch on remote
ssh "$name" "$system/bin/switch-to-configuration" switch
