{
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule (finalAttrs: {
  pname = "spire-tpm-plugin";
  version = "1.9.0";
  src = fetchFromGitHub {
    owner = "spiffe";
    repo = "spire-tpm-plugin";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vLA9ou+71bac6vB89EF21RKCGaGLbGg3gFRshgUuEWI=";
  };
  vendorHash = "sha256-lUpCKWjgVsn0/a1rijiLzrer3rfCn5SDkBAfTYgw0aU=";

  # TODO: tests need cgo and go-tpm-tools/simulator which isn't working (for now?)
  doCheck = false;
})
