{
  lib,
  buildNpmPackage,
  nodejs,
  typescript,
  makeWrapper,
}:
buildNpmPackage {
  pname = "jj-gh-stack";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./tsconfig.json
      ./src
    ];
  };

  npmDepsHash = "sha256-1ODSOCduP02tzEWgtwbmeh/seA2k5riWxhzXD0Vhf6c=";

  nativeBuildInputs = [
    makeWrapper
    typescript
  ];

  # Node runs the TypeScript sources directly; the build only type-checks them.
  buildPhase = ''
    runHook preBuild
    tsc -p .
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/jj-gh-stack
    npm prune --omit=dev --no-audit --no-fund
    cp -r src node_modules package.json $out/lib/jj-gh-stack/
    makeWrapper ${lib.getExe nodejs} $out/bin/jj-gh-stack \
      --add-flags $out/lib/jj-gh-stack/src/main.ts
    runHook postInstall
  '';

  meta = {
    description = "Stacked pull requests on GitHub with jj, using GitHub's native stacks";
    mainProgram = "jj-gh-stack";
  };
}
