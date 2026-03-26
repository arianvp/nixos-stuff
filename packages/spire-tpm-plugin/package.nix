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
  version = "1.10.1";
  src = fetchFromGitHub {
    owner = "arianvp";
    repo = "spire-tpm-plugin";
    rev = "push-kwxpnknqlouo";
    # tag = "v${finalAttrs.version}";
    hash = "sha256-SXlnXIU22oBBCwnD2gfkrzXCBlH0caBbIWlh/ARb/E0=";
  };

  proxyVendor = true;
  vendorHash = "sha256-RnEeTyLDoldxQ6VjdXDA9X0SebhtNsTeSth0h3dZx8Y=";

  nativeBuildInputs = [
    pkg-config
    tpm2-tools
    xxd
    openssl
    pwgen
  ];
  buildInputs = [ openssl ];
})
