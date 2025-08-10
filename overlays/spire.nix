final: prev: {
  spire = prev.spire.overrideAttrs (oldAttrs: {
    src = prev.fetchFromGitHub {
      owner = "arianvp";
      repo = "spire";
      rev = "8a49f5ccddec60a4eb8aacb222953c45f37567da";
      hash = "sha256-7/Go3nppaENStVsE8gLfXXpourQpjtZOU8Bq/Z2jtcE=";
    };
    vendorHash = "sha256-ax+6F2d7Sxwns/e5IRMqdbSni1O6Fu0DffVRanmPI3c=";
    doCheck = false;
  });
}
