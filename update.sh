#!/bin/sh

set -e

jj git fetch
jj new master
nix flake update

if ! jj diff --quiet; then
  jj describe -m 'nix flake update'
  jj bookmark advance master
  jj git push
else
  echo "No changes, abandoning empty commit"
  jj abandon
fi
