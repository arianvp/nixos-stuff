#!/usr/bin/env bash
set -euo pipefail

set -x 


# Useful note
# ssh-keygen -I "flokli-keys-0" -z +1 -n "flokli" -s yk-black/id_ed25519_sk_rk_ca_arian -V +52w flokli-1.pub flokli-2.pub 

# Cross-sign the keys. So I can lose one or the other.
# ssh-keygen -s yk-black/id_ed25519_sk_rk_ca_arian -I "yk-yellow/id_ed25519_sk_rk_arian" -n "arian" yk-yellow/id_ed25519_sk_rk_arian.pub
# ssh-keygen -s yk-yellow/id_ed25519_sk_rk_ca_arian -I "yk-black/id_ed25519_sk_rk_arian" -n "arian" yk-black/id_ed25519_sk_rk_arian.pub
