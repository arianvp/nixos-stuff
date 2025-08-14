{
  fetchFromGitHub,
  buildGoModule,
  fetchpatch,
}:
buildGoModule (finalAttrs: {
  pname = "spire-controller-manager";
  version = "0.6.2";
  src = fetchFromGitHub {
    owner = "spiffe";
    repo = "spire-controller-manager";
    rev = "v${finalAttrs.version}";
    hash = "sha256-7OJr5+qzV1ywEercRrjv5ya8K4CF8+DXuxUXBSKw2P0=";
  };
  vendorHash = "sha256-tH/3ToXxPJkzbUvY2JY85kHwyZX8n76wsE7yvKAU4aM=";
  subPackages = [ "cmd" ];
  postInstall = ''
    mv $out/bin/cmd $out/bin/spire-controller-manager
  '';
  patches = [
    (fetchpatch {
      url = "https://github.com/spiffe/spire-controller-manager/pull/561.patch";
      hash = "sha256-0uc14/8pa5yXII72L2Yj5StGBQFtAFYvhCTsGv+wL3Y=";
    })
  ];
})
