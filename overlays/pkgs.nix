self: super: {
  # protobuf-lol = self.protobuf;


  # We want to play nice with networkd, and we want to play nice with pkcs11
  /*openvpn = super.openvpn.override {
    pkcs11Support = true;
    inherit (super) pkcs11helper;
    };*/


  systemdPatched = super.systemd.overrideAttrs (old: old // {
    patches = old.patches ++ [
      (super.fetchpatch {
        url = "https://github.com/systemd/systemd/commit/56f8c219450fd192398e944d4613f24d326681fc.patch";
        sha256 = "sha256-i1lq5JPqB1HKvB8ylVBZmkpGup5cDVlYN0j2j3heqUE=";
      })
    ];
  });

}
