final: prev: {
  # jj-stack needs httpx2>=2.12
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (
      pyFinal: pyPrev:
      let
        src = final.fetchFromGitHub {
          owner = "pydantic";
          repo = "httpx2";
          tag = "v2.13.1";
          hash = "sha256-XgjFiSwc4xCyPJcTB/Exh838fUOKsT0JRrha7s70C50=";
        };
        bump =
          pkg:
          pkg.overridePythonAttrs {
            version = "2.13.1";
            inherit src;
            # wants uv-dynamic-versioning>=0.14.1, which is unused since nixpkgs sets UV_DYNAMIC_VERSIONING_BYPASS
            pypaBuildFlags = [ "--skip-dependency-check" ];
          };
      in
      {
        httpcore2 = bump pyPrev.httpcore2;
        httpx2 = bump pyPrev.httpx2;
      }
    )
  ];

  jj-stack = final.callPackage ../packages/jj-stack { python3Packages = final.python314Packages; };
}
