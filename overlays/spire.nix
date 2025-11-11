final: prev: {
  spire = prev.spire.overrideAttrs (oldAttrs: {
    patches = [
      (prev.fetchurl {
        url = "https://github.com/spiffe/spire/compare/v${oldAttrs.version}...arianvp:spire:socket-activation.patch";
        hash = "";
      })
    ];
  });

  spire-controller-manager = final.callPackage ../packages/spire-controller-manager/package.nix { };

  spire-tpm-plugin = final.callPackage ../packages/spire-tpm-plugin/package.nix { };
}
