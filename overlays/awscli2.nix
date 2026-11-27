final: prev:
let
  inherit (import ./lib.nix prev.lib) preferNewer;
in
{
  # For `aws sts get-scoped-credentials`, added in 2.42.0.
  awscli2 = preferNewer prev.awscli2 (
    (prev.awscli2.override {
      python3 = prev.python3.override {
        packageOverrides = pyFinal: pyPrev: {
          awscrt = pyPrev.awscrt.overridePythonAttrs (
            finalAttrs: prevAttrs: {
              version = "0.38.1";
              src = prevAttrs.src.override {
                inherit (finalAttrs) version;
                hash = "sha256-Dc6/qnDPB5EzzSNSEZ49Bem4yh0WIXNs+1TAPz1f7w8=";
              };
            }
          );
        };
      };
    }).overrideAttrs
      (
        finalAttrs: prevAttrs: {
          version = "2.42.4";
          src = prev.awscli2.src.override {
            tag = finalAttrs.version;
            hash = "sha256-uFM6eygUZarxWhcsNrtYsgRB8iHobIT3kVWTgCupDEA=";
          };
          disabledTestPaths = prevAttrs.disabledTestPaths ++ [
            # Needs localstub, a mock server that is not packaged
            "tests/blackbox"
          ];
          disabledTests = prevAttrs.disabledTests ++ [
            # Creates an awscrt S3 client, which needs the system trust store
            "test_upper_bound_matches_what_awscrt_accepts"
          ];
        }
      )
  );
}
