#!/usr/bin/env bash
set -e

tmpDir=$(mktemp -t -d nixos-rebuild.XXXXXX)
SSHOPTS="$NIX_SSHOPTS -o ControlMaster=auto -o ControlPath=$tmpDir/ssh-%n -o ControlPersist=60"

cleanup() {
    for ctrl in "$tmpDir"/ssh-*; do
        ssh -o ControlPath="$ctrl" -O exit dummyhost 2>/dev/null || true
    done
    rm -rf "$tmpDir"
}
trap cleanup EXIT


target="$1"
remote="$2"
profile=/nix/var/nix/profiles/system

remoteOrLocal() {
  if [ "$remote" == "localhost" ]; then 
    "$@"
  else
    ssh $SSHOPTS "$remote" "$@"
  fi
}


echo "Building closure"
result=$(nix-build -A "${target}.toplevel")

# todo copy if remote
if [ "$remote" != "localhost" ]; then
  echo "Copying closure"
  NIX_SSHOPTS=$SSHOPTS nix copy --no-check-sigs --to "ssh://$remote" "$result"
fi

echo "Setting profile"
remoteOrLocal sudo nix-env -p "$profile" --set "$result"

echo "Switching to configuration"
# pass any remaining arguments to the profile
remoteOrLocal sudo "${profile}/bin/switch-to-configuration" "${@:3}"

