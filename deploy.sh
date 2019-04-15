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

if [ $#  -ne 3 ]; then
  echo "Usage: ./deploy.sh <deployment> <remote> [switch|boot|kexec]"
  exit 1
fi

target="$1"
remote="$2"
action="$3"
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
if [ "$action" == "kexec" ]; then
  action2="switch"
else
  action2=$action
fi
# pass any remaining arguments to the profile
remoteOrLocal sudo "${profile}/bin/switch-to-configuration" "$action2"

if [ "$action" == "kexec" ]; then
  echo "Performing kexec"
  remoteOrLocal sudo kexec -l /run/current-system/kernel --initrd /run/current-system/initrd --reuse-cmdline
  remoteOrLocal sudo systemctl kexec
fi
