{ buildGoModule }:
buildGoModule {
  pname = "he-ddns";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-hifB6Db+8dnLtSYzGWPwrmGUpkUOMgG47FZyD3Py6M8=";
  meta.mainProgram = "he-ddns";
}
