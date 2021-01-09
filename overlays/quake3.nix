final: prev: {
  quake3_assets = prev.stdenv.mkDerivation {
    name = "quake3-arena";
    pak0 = /home/arian/q3/baseq3/pak0.pk3;
    buildCommand = ''
      install -D -m644 $pak0 $out/baseq3/pak0.pk3;
    '';
  };
  quake3 = prev.quake3wrapper {
    paks = [ final.quake3_assets final.quake3pointrelease ];
  };
}
