#!/usr/bin/env bash

set -euo pipefail

# generate a non-resident hardware-backed ssh key with the attestation embedded in the certificate on demand

scope="${1:-}"
user="${2:-}"
application="ssh:$scope"
comment="$application"

filename="id_ed25519_sk${resident:+_rk}${scope:+_${scope}}${user:+_${user}}"
pubkey="${filename}.pub"
cert="${filename}-cert.pub"
attestation="${filename}.att"

# NOTE: *not* resident. We generate ssh key on-demand. 
ssh-keygen -t ed25519-sk \
	-O verify-required \
	-O "user=$user" \
	-O "application=$application" \
	-C "$comment" \
	-N "" \
	-f "$filename" \
	-O write-attestation="$attestation"

certificate_identity="${application}${user:+/$user}"
attestation_object=$(base64 -w0 "$attestation")

# Embed the attestation in a self-signed certificate
ssh-keygen \
	-I "$certificate_identity" \
	-s "$filename" \
	-O "extension:attestation-object@arianvp.me:$attestation_object" \
	-V "+1h" \
        "$pubkey"

# How is this useful? The server can now attest that the key is hardware-backed
# TODO: Do we need to add a challenge?

# TODO: Store in large-blob



