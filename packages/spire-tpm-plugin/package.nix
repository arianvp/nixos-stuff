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
    hash = "sha256-8235RO+o5rZ6JsXvfoIS/OaacmsyC7tkYckTVZv5uEA=";
  };

  proxyVendor = true;
  vendorHash = "sha256-cENDkx/iz6H/AhAO1lKypHhOFz+F3gC3bMg8Jw7eeo0=";

  nativeBuildInputs = [
    pkg-config
    tpm2-tools
    xxd
    openssl
    pwgen
  ];
  buildInputs = [ openssl ];
})
