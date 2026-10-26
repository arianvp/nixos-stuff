{ lib, buildGoModule }:
buildGoModule {
  pname = "spire-credentialcomposer-x509";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.fileFilter (
      file: lib.hasSuffix ".go" file.name || file.name == "go.mod" || file.name == "go.sum"
    ) ./.;
  };
  vendorHash = "sha256-iYx7i1bPWNFwPZyspFXzSr5I89hcEabSbjskeFRKNsM=";
  env.CGO_ENABLED = 0;

  meta = {
    description = "SPIRE CredentialComposer plugin that sets X509-SVID subjects and IP SANs by SPIFFE ID";
    mainProgram = "spire-credentialcomposer-x509";
  };
}
