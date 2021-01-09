final: prev: {
  apl385 = prev.stdenv.mkDerivation {
    name = "apl385";
    src = prev.fetchurl {
      url = "http://apl385.com/fonts/apl385.zip";
      sha256 = "132qfsnx0v6qf8x8iy3flivv449nz42nnpkwjysmz65w6wqxpk1g";
    };
    buildInputs = [ prev.unzip ];
    sourceRoot = ".";
    installPhase = ''
      out1=$out/share/fonts/apl385
      mkdir -p $out1
      cp ./Apl385.ttf $out1
    '';
  };
}
