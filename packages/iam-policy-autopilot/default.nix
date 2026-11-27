{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  makeBinaryWrapper,
}:
let
  # Prebuilt upstream release binaries. A source build needs the boto3,
  # botocore, aws-sdk-java-v2 and terraform-provider-aws submodules, the last
  # two over git@ URLs that the fetchers can't clone.
  targets = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-shA9lEhbym0IcylAM8zhUOsPP+Klawi8GiYuAbbdXIw=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-vRtPDafCJ10zJq33xPKtFDs2mkNAlnVVsbO7xC5k2gY=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-A2vYD1UumUaecLjmFNxtQN9MP357eEZaay/BPXm+F/w=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-c33oyUPjrL966O9DplW0thMySmg5qvHj4iMoWfPKoZA=";
    };
  };
  platform = targets.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "iam-policy-autopilot";
  version = "0.4.0";

  src = fetchurl {
    url = "https://github.com/awslabs/iam-policy-autopilot/releases/download/${finalAttrs.version}/iam-policy-autopilot-${finalAttrs.version}-${platform.target}.tar.gz";
    inherit (platform) hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    makeBinaryWrapper
  ]
  ++ lib.optional stdenvNoCC.hostPlatform.isLinux autoPatchelfHook;

  installPhase = ''
    runHook preInstall
    install -Dm755 iam-policy-autopilot $out/libexec/iam-policy-autopilot
    makeWrapper $out/libexec/iam-policy-autopilot $out/bin/iam-policy-autopilot \
      --set-default DISABLE_IAM_POLICY_AUTOPILOT_TELEMETRY true
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    $out/bin/iam-policy-autopilot --version | grep -F ${finalAttrs.version}
  '';

  meta = {
    description = "Generates baseline IAM policies from the AWS SDK calls in code";
    homepage = "https://github.com/awslabs/iam-policy-autopilot";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = lib.attrNames targets;
    mainProgram = "iam-policy-autopilot";
  };
})
