self: super: {
  # protobuf-lol = self.protobuf;


  # We want to play nice with networkd, and we want to play nice with pkcs11
  openvpn = super.openvpn.override {
    pkcs11Support = true;
    inherit (super) pkcs11helper;
  };

  wire-desktop = super.wire-desktop.overrideAttrs (oldAttrs: rec {

    desktopItem = self.makeDesktopItem {
      name = "wire-desktop";
      exec = "wire-desktop %U";
      icon = "wire-desktop";
      comment = "Secure messenger for everyone";
      desktopName = "Wire";
      genericName = "Secure messenger";
      categories = "Network;InstantMessaging;Chat;VideoConference";
      extraEntries = ''
        StartupWMClass=Wire
      '';
    };

    installPhase = ''
      mkdir -p "$out"
      cp -R "opt" "$out"
      cp -R "usr/share" "$out/share"
      chmod -R g-w "$out"

      # Patch wire-desktop
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${oldAttrs.rpath}:$out/opt/Wire" \
        "$out/opt/Wire/wire-desktop"

      # Symlink to bin
      mkdir -p "$out/bin"
      ln -s "$out/opt/Wire/wire-desktop" "$out/bin/wire-desktop"

      # Desktop file
      mkdir -p "$out/share/applications"
      cp "${desktopItem}/share/applications/"* "$out/share/applications"
    '';
  });

}
