#!/usr/bin/env bash
set -euo pipefail

set -x 
# Cross-sign the keys. So I can lose one or the other.
ssh-keygen -s yk-black/id_ed25519_sk_rk_ca_arian -I "yk-yellow/id_ed25519_sk_rk_arian" -n "arian" yk-yellow/id_ed25519_sk_rk_arian.pub
ssh-keygen -s yk-yellow/id_ed25519_sk_rk_ca_arian -I "yk-black/id_ed25519_sk_rk_arian" -n "arian" yk-black/id_ed25519_sk_rk_arian.pub
