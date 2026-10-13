{ lib, buildGoModule }:
buildGoModule {
  pname = "kube-kms-openbao";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (
      file: lib.hasSuffix ".go" file.name || file.name == "go.mod" || file.name == "go.sum"
    ) ./.;
  };
  vendorHash = "sha256-m5dDdein+dBXRF/dJK08F0/8z1flEWS+50AyjJ3LB7k=";
  env.CGO_ENABLED = 0;

  meta = {
    description = "Kubernetes KMS v2 plugin that encrypts with the OpenBao transit secrets engine";
    mainProgram = "kube-kms-openbao";
  };
}
