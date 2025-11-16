#!/usr/bin/env bash

set -euo pipefail

scope="${1:-}"

user="$USER"
application="ssh:$scope"
comment="$application"

ssh-keygen -t ed25519-sk \
  -O resident \
  -O verify-required \
  -O "user=$user" \
  -O "application=$application" \
  -C "$comment" \
  -N "" \
  -f "id_ed25519_sk_rk${scope:+_${scope}}${user:+_${user}}"



