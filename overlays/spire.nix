final: prev: {
  /*go_1_25_3 = prev.go_1_25.overrideAttrs (
    finalAttrs: prevAttrs: {
      version = "1.25.3";
      src = final.fetchurl {
        url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
        hash = "sha256-qBpLpZPQAV4QxR4mfeP/B8eskU38oDfZUX0ClRcJd5U=";
      };
    }
  );

  buildGo1253Module = prev.buildGoModule.override {
    go = final.go_1_25_3;
  };*/

  spire =
    (prev.spire.override { buildGoModule = final.buildGo125Module; }).overrideAttrs
      (oldAttrs: {
        src = prev.fetchFromGitHub {
          owner = "arianvp";
          repo = "spire";
          rev = "socket-activation";
          hash = "sha256-t3AvqylZnT6/k7FI/XEv6BD2z7VWYkde0Ei1V3K5nck=";
        };
        vendorHash = "sha256-Mq3wR2kCdiyaaWMDCDjSN/KlKi6vXwXvo6mNptI4BYc=";
      });

  spire-controller-manager = final.callPackage ../packages/spire-controller-manager/package.nix { };

  spire-tpm-plugin = final.callPackage ../packages/spire-tpm-plugin/package.nix { };
}
