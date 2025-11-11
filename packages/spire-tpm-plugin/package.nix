{
  fetchFromGitHub,
  buildGoModule,
  pkg-config,
  openssl,
  tpm2-tools,
  xxd,
  pwgen,
}:
buildGoModule (finalAttrs: {
  pname = "spire-tpm-plugin";
  version = "1.10.0pre";
  src = fetchFromGitHub {
    owner = "arianvp";
    repo = "spire-tpm-plugin";
    rev = "f2861cc26599d79d6bb625ce56e6dad793f354cf";
    # tag = "v${finalAttrs.version}";
    hash = "sha256-iIlRDq1eId2iYgDTQyL5uUyhVtwmd3PCm2ZHbbvk+/c=";
  };

  vendorHash = "sha256-0HkJdgIweB8SnnTsOgl3m3XL72OBhw+nBbe9GuTMY20=";

  nativeBuildInputs = [
    pkg-config
    tpm2-tools
    xxd
    openssl
    pwgen
  ];
  buildInputs = [ openssl ];

  # TODO: tests seem genuinely busted. First openssl errors. When I Fixed those then
  # actually the simulator had no EKCert at all.
  # The repo isn't running CI whatsoever. So not convinced it wasn't borked before me
  doCheck = false;
})
