{
  fetchFromGitHub,
  buildGoModule,
  fetchpatch,
}:
buildGoModule (finalAttrs: {
  pname = "spire-controller-manager";
  version = "0.6.3pre";
  src = fetchFromGitHub {
    owner = "spiffe";
    repo = "spire-controller-manager";
    #rev = "v${finalAttrs.version}";
    rev = "2128de4f24b29d48a22eae5fee2cf043cf943e6e";
    hash = "sha256-L1QhlkTakEVXj5sPWP6rjPiDF+FL1652b4pWx+BW15s=";
  };
  vendorHash = "sha256-uBfwvOFpYHwCh9f/aH3aozKyy/Z05MA/S/P+mIaIouA=";
  subPackages = [ "cmd" ];
  postInstall = ''
    mv $out/bin/cmd $out/bin/spire-controller-manager
  '';

  meta.mainProgram = "spire-controller-manager";
})
