# This overlay adds Ormolu straight from GitHub.
final: prev:

let source = prev.fetchFromGitHub {
      owner = "tweag";
      repo = "ormolu";
      rev = "3137345dc334e1dbe7e139d4ddd22e8184d6fbd2"; # update as necessary
      sha256 = "1yxvl028h3mbkkqq3r0d5mfxifz3phrrfzqfzc7dykw3b5c9z4hq"; # self.lib.fakeSha256;
    };
    ormolu = import source { pkgs = final; };
in {
  haskell = prev.haskell // {
    packages = prev.haskell.packages // {
      "${ormolu.ormoluCompiler}" = prev.haskell.packages.${ormolu.ormoluCompiler}.override {
        overrides = ormolu.ormoluOverlay;
      };
    };
  };
}
