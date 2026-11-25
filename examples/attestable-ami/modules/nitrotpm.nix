# Predicts the PCR values NitroTPM will report for the UKI, for use in a KMS key
# policy. With ./secure-boot.nix, PCR7 covers the enrolled UEFI variables.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  nitrotpm-tools = pkgs.buildPackages.nitrotpm-tools.overrideAttrs (previousAttrs: {
    patches = previousAttrs.patches or [ ] ++ [ ./nitro-tpm-pcr-compute-db-digests.patch ];
  });
  secureBoot = config.system.build.secureBoot or null;
in
{
  system.build.pcrs =
    pkgs.runCommand "${config.image.baseName}-pcrs.json" { nativeBuildInputs = [ nitrotpm-tools ]; }
      ''
        nitro-tpm-pcr-compute --image ${config.system.build.uki}/${config.system.boot.loader.ukiFile} \
          ${
            lib.optionalString (
              secureBoot != null
            ) "--PK ${secureBoot}/PK.esl --db ${secureBoot}/db.esl --dbx ${secureBoot}/dbx.esl"
          } \
          > $out
      '';
}
