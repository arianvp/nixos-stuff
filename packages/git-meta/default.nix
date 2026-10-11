{
  lib,
  rustPlatform,
  fetchFromGitHub,
  git,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "git-meta";
  version = "0.1.12-unstable-2026-10-08";

  src = fetchFromGitHub {
    owner = "git-meta";
    repo = "git-meta";
    rev = "38a237dbc3b7d6ada306937ad42d66c547f6a658";
    hash = "sha256-cONKrPI2hhOaX9nJaSVhIm7f5HG61WMzQVrYWltUEaU=";
  };

  cargoHash = "sha256-QCdXz7Em7LffS548GRqy/pr1+pW185yt1WHGazISviY=";

  cargoBuildFlags = [
    "-p"
    "git-meta-cli"
  ];
  cargoTestFlags = finalAttrs.cargoBuildFlags;
  nativeCheckInputs = [ git ];

  meta = {
    description = "Structured metadata for Git objects, stored under refs/meta";
    homepage = "https://git-meta.com/";
    license = lib.licenses.mit;
    mainProgram = "git-meta";
  };
})
