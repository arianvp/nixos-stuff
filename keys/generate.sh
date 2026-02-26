#!/usr/bin/env bash

set -euo pipefail


# scope is the purpose of the key. empty scope is just your normal generic ssh key
# example scopes : git , ca,  sign,
# user is when you have multiple instances of the same purpose. e.g. if you have multiple identities.
# empty user is the "default" identity.  Useful if you have both "work" and non-work identities

scope="${1:-}"
user="${2:-}"
application="ssh:$scope"
comment="${user:+$user@}$application"

# TODO: I might wanna do configurable resident keys in the future
resident=1

# same naming convention that `ssh-keygen -K` uses. For some reason ssh-keygen and ssh-keygen -K are not aligned
suffix="${scope:+_${scope}}${user:+_${user}}"
file="id_ed25519_sk${resident:+_rk}${scope:+_${scope}}${user:+_${user}}"

ssh-keygen -t ed25519-sk \
  -O resident \
  -O verify-required \
  -O "user=$user" \
  -O "application=$application" \
  -C "$comment" \
  -N "" \
  -f "$file" \
  -O write-attestation="${file}.att"
