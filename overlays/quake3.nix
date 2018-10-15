self: super: {
  quake3_assets = super.stdenv.mkDerivation {
    name = "quake3-arena";
    pak0 = /home/arian/q3/baseq3/pak0.pk3;
    buildCommand = ''
      install -D -m644 $pak0 $out/baseq3/pak0.pk3;
    '';
  };
  quake3 = super.quake3wrapper {
    paks = [ self.quake3_assets self.quake3pointrelease ];
  };
}
