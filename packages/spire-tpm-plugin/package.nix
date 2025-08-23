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
    rev = "fa66b8e18374f12f44b452299c6c9d4e2eb02bfe";
    # tag = "v${finalAttrs.version}";
    hash = "sha256-WkdwU6y20P0FbjOmZUin8/jfeXJ0zbTYxEaONeTisZA=";
  };
  vendorHash = "sha256-0HkJdgIweB8SnnTsOgl3m3XL72OBhw+nBbe9GuTMY20=";

  # TODO: tests need cgo and go-tpm-tools/simulator which isn't working (for now?)
  doCheck = false;
})
