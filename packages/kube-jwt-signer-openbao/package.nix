{ lib, buildGoModule }:
buildGoModule {
  pname = "kube-jwt-signer-openbao";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (
      file: lib.hasSuffix ".go" file.name || file.name == "go.mod" || file.name == "go.sum"
    ) ./.;
  };
  vendorHash = "sha256-hdMYdYpExqWzZF461iFxvLMFwS53Yrkyr5bHNY08bcs=";
  env.CGO_ENABLED = 0;

  meta = {
    description = "External service account token signer for kube-apiserver that signs with the OpenBao transit secrets engine";
    mainProgram = "kube-jwt-signer-openbao";
  };
}
