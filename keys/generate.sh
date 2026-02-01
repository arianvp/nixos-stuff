#!/usr/bin/env bash

set -euo pipefail

scope="${1:-}"
user="${2:-}"
application="ssh:$scope"
comment="$application"


suffix="${scope:+_${scope}}${user:+_${user}}"

file="id_ed25519_sk_${resident:+rk}${scope:+_${scope}}${user:+_${user}}"

ssh-keygen -t ed25519-sk \
  -O resident \
  -O verify-required \
  -O "user=$user" \
  -O "application=$application" \
  -C "$comment" \
  -N "" \
  -f "$file" \
  -O write-attestation="${file}.att"



