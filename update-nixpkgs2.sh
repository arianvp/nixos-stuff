#!/bin/sh
channel="nixos-19.09"

latest_url=$(curl -L -I -s -o /dev/null -w %{url_effective} "https://nixos.org/channels/$channel/nixexprs.tar.xz")

echo $latest_url

latest_hash=$(nix-prefetch-url -vv --unpack "$latest_url")

echo $latest_hash

cat <<EOF > "$channel.nix"
import (fetchTarball {
  url = "$latest_url";
  sha256 = "$latest_hash";
})
EOF
