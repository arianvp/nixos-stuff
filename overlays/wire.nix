final: prev: {
  # NOTE: This is the internal development-build of wire. It is not meant for
  # public consumption and it comes with NO warranty whatsoever
  wire-desktop-internal = prev.wire-desktop.overrideAttrs (old: old // rec {
    version = "3.21.45-internal-45";
    src = prev.fetchurl {
      url = "https://wire-app.wire.com/linux-internal/debian/pool/main/WireInternal-3.21.45-internal_amd64.deb";
      sha256 = "1aj73zssj6n30n72b6kkxmgykn8vyk3ym1l8z1cd8xas948l90mb";
    };
    postFixup = ''
      makeWrapper $out/opt/WireInternal/wire-desktop-internal $out/bin/wire-desktop  "''${gappsWrapperArgs[@]}"
    '';
  });
}
