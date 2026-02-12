#!/usr/bin/env bash

set -e

issuer=https://cloud.digitalocean.com/v1/oauth
authorization_endpoint="${issuer}/authorize"
token_endpoint="${issuer}/token"

client_id=e5d7730dbd4108be3491a7c661b2074ffab54ceaecf4882e07df05ce1396d32c

echo "Visit https://cloud.digitalocean.com/account/api/applications/details/108840?i=0752ae to get client_secret"

nix run nixpkgs#oauth2c -- \
  https://cloud.digitalocean.com/v1/oauth \
  --grant-type authorization_code \
  --authorization-endpoint  https://cloud.digitalocean.com/v1/oauth/authorize \
  --token-endpoint https://cloud.digitalocean.com/v1/oauth/token \
  --auth-method client_secret_post \
  --response-types code \
  --response-mode form_post \
  --client-id "$client_id" \
  --prompt none

