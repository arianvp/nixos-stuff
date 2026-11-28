# Predicts the PCR values NitroTPM will report for the UKI, for use in a KMS key
# policy.
{ config, pkgs, ... }:
{
  system.build.pcrs =
    pkgs.runCommand "${config.image.baseName}-pcrs.json"
      { nativeBuildInputs = [ pkgs.buildPackages.nitrotpm-tools ]; }
      ''
        nitro-tpm-pcr-compute --image ${config.system.build.uki}/${config.system.boot.loader.ukiFile} > $out
      '';
}
