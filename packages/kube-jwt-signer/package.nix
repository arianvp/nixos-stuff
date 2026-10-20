{ lib, buildGoModule }:
buildGoModule {
  pname = "kube-jwt-signer";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (
      file: lib.hasSuffix ".go" file.name || file.name == "go.mod" || file.name == "go.sum"
    ) ./.;
  };
  vendorHash = "sha256-+hyY12Yxt/CJOeiopZisWjBLE89IeopuYdM9RF/l7Ps=";
  env.CGO_ENABLED = 0;

  meta = {
    description = "External service account token signer for kube-apiserver that exchanges public keys over SPIFFE mTLS";
    mainProgram = "kube-jwt-signer";
  };
}
