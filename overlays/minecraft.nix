self: super: {
  minecraft-server = super.minecraft-server.overrideAttrs (_:
    rec {
      name = "minecraft-server-${version}";
      version = "1.13.1";
      src = super.fetchurl {
        url = "https://launcher.mojang.com/v1/objects/fe123682e9cb30031eae351764f653500b7396c9/server.jar";
        sha256 = "1lak29b7dm0w1cmzjn9gyix6qkszwg8xgb20hci2ki2ifrz099if";
      };
  });
}
