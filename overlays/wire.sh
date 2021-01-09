#!/bin/sh
f=$(mktemp)
curl -s https://wire-app.wire.com/linux-internal/debian/dists/stable/main/binary-amd64/Packages > $f
filename=$(cat $f | awk '/Filename:/ { print $2 }')
version=$(cat $f | awk '/Version:/ { print $2 }')
sha256_=$(cat $f | awk '/SHA256:/ { print $2 }')
sha256=$(nix-hash --type sha256 --to-base32 ${sha256_})

cat <<EOF
final: prev: {
  # NOTE: This is the internal development-build of wire. It is not meant for
  # public consumption and it comes with NO warranty whatsoever
  wire-desktop-internal = super.wire-desktop.overrideAttrs (old: old // rec {
    version = "$version";
    src = super.fetchurl {
      url = "https://wire-app.wire.com/linux-internal/debian/$filename";
      sha256 = "$sha256";
    };
    postFixup = ''
      makeWrapper \$out/opt/WireInternal/wire-desktop-internal \$out/bin/wire-desktop  "''\${gappsWrapperArgs[@]}"
    '';
  });
}
EOF
