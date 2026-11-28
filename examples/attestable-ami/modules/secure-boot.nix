# Turns on UEFI Secure Boot for the UKI of ./single-uki.nix, without a signing
# key. db holds the UKI's Authenticode hash rather than a certificate, so the
# firmware boots exactly this UKI and nothing else, and systemd-stub ignores
# kernel command lines that boot entries pass it. The platform key is a
# certificate that kmodigest derives from a fixed string, so nobody has its
# private key, and KEK stays empty: nobody can change db afterwards, not even
# whoever built the image.
#
# `system.build.secureBoot` holds the UEFI variable store to register the AMI
# with, and the variables, for predicting PCR7.
{ config, pkgs, ... }:
let
  # Owns the platform key and the db entry; any fixed GUID will do.
  owner = "6a4f1c1e-3f0b-4b8e-9c2d-5a7e8b9c0d1e";

  uki = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
in
{
  system.build.secureBoot =
    pkgs.runCommand "${config.image.baseName}-secure-boot"
      {
        nativeBuildInputs = with pkgs.buildPackages; [
          jq
          kmodigest
          libfaketime
          pesign
          python3Packages.virt-firmware
        ];
      }
      ''
        mkdir $out

        # kmodigest only signs files named like kernel modules.
        echo -n "${config.image.baseName} has no platform key" > platform-key.ko
        kmodigest platform-key.ko
        cp platform-key.ko.cer $out/PK.cer
        echo -n ${owner} > $out/owner

        pesign --hash --in ${uki} | cut -d ' ' -f 1 > $out/uki.sha256

        # The variables' timestamps are the only thing that would differ
        # between builds.
        faketime '1970-01-01 00:00:01' virt-fw-vars \
          --set-pk ${owner} platform-key.ko.cer \
          --add-db-hash ${owner} "$(cat $out/uki.sha256)" \
          --no-microsoft --secure-boot \
          --output-aws $out/uefi-data.aws --output-json variables.json

        for variable in PK db dbx; do
          jq --raw-output --arg name $variable '.variables[] | select(.name == $name) | .data' variables.json \
            | tr a-f A-F | basenc --base16 --decode > $out/$variable.esl
        done
      '';
}
