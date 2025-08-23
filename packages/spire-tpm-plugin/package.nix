{
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule (finalAttrs: {
  pname = "spire-tpm-plugin";
  version = "1.10.0pre";
  src = fetchFromGitHub {
    owner = "arianvp";
    repo = "spire-tpm-plugin";
    rev = "87464a463cfef913d11a8b472ea6005a8ed537bb";
    # tag = "v${finalAttrs.version}";
    hash = "sha256-kvFKq8YJpDTgTY4Wkiyn/LfqgkEl43QrYjjz3CMD32k=";
  };
  vendorHash = "sha256-0HkJdgIweB8SnnTsOgl3m3XL72OBhw+nBbe9GuTMY20=";

  # TODO: tests need cgo and go-tpm-tools/simulator which isn't working (for now?)
  doCheck = false;
})
