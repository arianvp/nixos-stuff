self: super: {
  # protobuf-lol = self.protobuf;


  # We want to play nice with networkd, and we want to play nice with pkcs11
  /*openvpn = super.openvpn.override {
    pkcs11Support = true;
    inherit (super) pkcs11helper;
  };*/

}
