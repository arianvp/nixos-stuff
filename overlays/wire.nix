self: super: {
  # NOTE: This is the internal development-build of wire. It is not meant for
  # public consumption and it comes with NO warranty whatsoever
  wire-desktop-internal = super.wire-desktop.overrideAttrs (old: old // rec {
    version = "3.19.37-internal-37";
    src = super.fetchurl {
      url = "https://wire-app.wire.com/linux-internal/debian/pool/main/WireInternal-3.19.37-internal_amd64.deb";
      sha256 = "11n1h9xy80mx8imr758hs0pj85mkhig4gx618y81k7z2gw87m4ha";
    };

    postFixup = ''
      makeWrapper $out/opt/WireInternal/wire-desktop-internal $out/bin/wire-desktop \
        "''${gappsWrapperArgs[@]}"
    '';
  });
}
