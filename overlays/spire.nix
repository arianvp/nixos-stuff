final: prev: {
  spire = prev.spire.overrideAttrs (oldAttrs: {
    src = prev.fetchFromGitHub {
      owner = "arianvp";
      repo = "spire";
      rev = "3291b0056446b46637672f5f136bf78a619e23db";
      hash = "sha256-MMAKZL4yfq+VBMX6hWgJO4qTi8Run0TnvaN50nk1CNk=";
    };
    vendorHash = "sha256-ax+6F2d7Sxwns/e5IRMqdbSni1O6Fu0DffVRanmPI3c=";
  });
}
