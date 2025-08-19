final: prev: {
  spire = prev.spire.overrideAttrs (oldAttrs: {
    src = prev.fetchFromGitHub {
      owner = "arianvp";
      repo = "spire";
      rev = "ca0c5a87d8c1bca9ab8f84af3b0db77578750527";
      hash = "sha256-1rOm28YpWsUQbnOPRAyZh2TxChrq9n3Qxp0hkQBl0JU=";
    };
    vendorHash = "sha256-ax+6F2d7Sxwns/e5IRMqdbSni1O6Fu0DffVRanmPI3c=";
    doCheck = false;

    subPackages = oldAttrs.subPackages ++ [ "support/oidc-discovery-provider" ];
  });

  spire-controller-manager = final.callPackage ../packages/spire-controller-manager/package.nix { };

  spire-tpm-plugin = final.callPackage ../packages/spire-tpm-plugin/package.nix { };
}
