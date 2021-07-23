self: super: {
  # NOTE: This is the internal development-build of wire. It is not meant for
  # public consumption and it comes with NO warranty whatsoever
  wire-desktop-internal = super.wire-desktop.overrideAttrs (old: old // rec {
    version = "3.27.53-internal-53";
    src = super.fetchurl {
      url = "https://wire-app.wire.com/linux-internal/debian/pool/main/WireInternal-3.27.53-internal_amd64.deb";
      sha256 = "1h938yhkwzgf6campq3gaclgc54dnjgpzqk55nr5ywdgia6396sl";
    };
    postFixup = ''
      makeWrapper $out/opt/WireInternal/wire-desktop-internal $out/bin/wire-desktop  "''${gappsWrapperArgs[@]}"
    '';
  });
}
