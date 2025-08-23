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
    rev = "f2861cc26599d79d6bb625ce56e6dad793f354cf";
    # tag = "v${finalAttrs.version}";
    hash = "sha256-iIlRDq1eId2iYgDTQyL5uUyhVtwmd3PCm2ZHbbvk+/c=";
  };
  vendorHash = "sha256-0HkJdgIweB8SnnTsOgl3m3XL72OBhw+nBbe9GuTMY20=";

  # TODO: tests need cgo and go-tpm-tools/simulator which isn't working (for now?)
  doCheck = false;
})
