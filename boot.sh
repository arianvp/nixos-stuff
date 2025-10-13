#!/usr/bin/env bash

# TODO: the path to the entry
installable=nixpkgs#pkgsStatic.busybox

root=$(realpath $1)
boot=$(realpath $2)
store="local?root=$root"
state="$root/nix/var/nix"
profiles="$state/profiles"
profile_name="boot"
profile="$profiles/boot"
tries=3
max_instances=3

# Build the files needed for boot
nix build --eval-store auto --store "$store" --no-link --profile "$profile" "$installable"

# garbage collect old generations
nix-env --delete-generations "+${max_instances}" --profile "$profile" --store "$store"
nix-store --gc --store "$store"


# This is just gonna be a single simple entry.
cat <<EOF
[Source]
Type=regular-file
Path=$profiles
MatchPattern=$profile_name-@v-link/entry.conf
[Target]
Type=regular-file
Path=/entries
PathRelativeTo=boot
MatchPattern=nixos-generation_@v+@l-@d.conf \
             nixos-generation_@v+@l.conf \
             nixos-generation_@v.conf
TriesLeft=${tries}
TriesDone=0
InstancesMax=${instances_max}
EOF


# Copy required paths
# TODO: no symlinks. no permissions. Just copies and deletes. that's all that it supports
# TODO: --delete
mkdir -p "$boot/nix"
rsync --recursive --archive --delete --progress "$root/nix/store" "$boot/nix"

# to be honest. This is perfect. Solves *all* issues

