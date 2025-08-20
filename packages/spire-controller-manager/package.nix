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
    #rev = "v${finalAttrs.version}";
    rev = "421205d5679befbbb9bfb8a5b03260744adedd6a";
    hash = "sha256-kf5FRwrvGyroYVn4rWnBCWOj9OMbfCX57Qb/bjz8zW8=";
  };
  vendorHash = "sha256-1M5+D5SVWmr0pkwx7N5mfYqofO9cU0uY8ib8jYGvmlw=";
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

  meta.mainProgram = "spire-controller-manager";
})
