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
  rev = "push-nqnpzowlptmz";
  src = /home/arian/Projects/spire-tpm-plugin;
  /*src = fetchFromGitHub {
    owner = "arianvp";
    repo = "spire-tpm-plugin";
    rev = "push-nqnpzowlptmz";
    # tag = "v${finalAttrs.version}";
    hash = "sha256-FKVI0ZFR6tzy06M4nLVdq6qVK9kyG4WEydeQIqPs/88=";
    };*/

  vendorHash = "sha256-00duHqpPRPzs57yo3BLpMGvo/ntYcxzZqz6nk/jchRw=";

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
