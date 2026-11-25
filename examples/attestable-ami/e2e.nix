# Packages ./e2e.py, which tests the examples end to end on EC2, with the
# images it uploads.
#
# The KMS key only exists once the test runs, so its image pins an alias that
# the test points at the key, rather than the key's ARN. An administrator of
# the account could point the alias elsewhere, which is why real images pin
# the ARN.
{
  lib,
  writers,
  python3Packages,
  appliance,
  predict-pcr12,
}:
let
  alias = "alias/attestable-ami-e2e";

  e2e = appliance.extendModules {
    modules = [ { services.kms-decrypt.keyId = lib.mkForce alias; } ];
  };
  image = e2e.config.system.build.images.attestable-ami;
  inherit (image.passthru.config.system.build) pcrs;
  secureBoot = image.passthru.config.system.build.secureBoot or null;

  # The Secure Boot variables of a UKI that differs in nothing but its command
  # line. Registered with them, the image's own UKI is the one not in db.
  otherSecureBoot =
    (e2e.extendModules { modules = [ { boot.kernelParams = [ "other" ]; } ]; })
    .config.system.build.images.attestable-ami.passthru.config.system.build.secureBoot;

  raw = image: "${image}/${image.passthru.filePath}";
in
writers.writePython3Bin "e2e"
  {
    libraries = with python3Packages; [
      # For credentials from `aws login`.
      awscrt
      boto3
      cryptography
    ];
    flakeIgnore = [ "E501" ];
  }
  (
    lib.replaceStrings
      [
        "@alias@"
        "@image@"
        "@pcrs@"
        "@predict_pcr12@"
        "@uefi_data@"
        "@other_uefi_data@"
        "@sandbox@"
      ]
      [
        alias
        (raw image)
        "${pcrs}"
        "${predict-pcr12}/bin/predict-pcr12"
        (lib.optionalString (secureBoot != null) "${secureBoot}/uefi-data.aws")
        (lib.optionalString (secureBoot != null) "${otherSecureBoot}/uefi-data.aws")
        (lib.optionalString (e2e.config.services ? nitro-sandbox) "1")
      ]
      (builtins.readFile ./e2e.py)
  )
