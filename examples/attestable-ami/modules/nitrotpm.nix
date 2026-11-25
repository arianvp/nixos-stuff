# Predicts the PCR values NitroTPM will report once the system is up, for use
# in a KMS key policy: what the firmware measures (PCR 4, 7 and 12) as computed
# by nitro-tpm-pcr-compute, and what systemd measures (PCR 11).
{ config, pkgs, ... }:
{
  imports = [ ./measured-boot.nix ];

  system.build.pcrs =
    pkgs.runCommand "${config.image.baseName}-pcrs.json"
      {
        nativeBuildInputs = with pkgs.buildPackages; [
          jq
          nitrotpm-tools
        ];
      }
      ''
        nitro-tpm-pcr-compute --image ${config.system.build.uki}/${config.system.boot.loader.ukiFile} \
          | jq --slurpfile pcr11 ${config.system.build.pcr11} \
            '.Measurements.PCR11 = $pcr11[0].sha384[0].hash' > $out
      '';
}
