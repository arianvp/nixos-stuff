# Measures the boot phases (enter-initrd, leave-initrd, sysinit, ready) into
# PCR 11, after systemd-stub measured the UKI's sections there, and predicts
# the value PCR 11 has once the system is up.
{ config, pkgs, ... }:
let
  sections = [
    "linux"
    "osrel"
    "cmdline"
    "initrd"
    "ucode"
    "splash"
    "dtb"
    "dtbauto"
    "uname"
    "sbat"
    "pcrpkey"
    "profile"
    "hwids"
    "efifw"
  ];
in
{
  boot.initrd.systemd.tpm2.pcrphases.enable = true;
  systemd.tpm2.pcrphases.enable = true;

  # systemd-stub measures each section as loaded into memory; `ukify inspect`
  # extracts exactly those bytes, and only for the sections the UKI has.
  system.build.pcr11 =
    pkgs.runCommand "${config.image.baseName}-pcr11.json"
      { nativeBuildInputs = [ pkgs.buildPackages.systemdUkify ]; }
      ''
        uki=${config.system.build.uki}/${config.system.boot.loader.ukiFile}
        ukify inspect "$uki" --json=short ${
          toString (map (s: "--section=.${s}:binary@${s}") sections)
        } > /dev/null

        args=()
        for section in ${toString sections}; do
          if [ -e "$section" ]; then
            args+=("--$section=$section")
          fi
        done

        ${pkgs.buildPackages.systemd}/lib/systemd/systemd-measure calculate "''${args[@]}" \
          --phase=enter-initrd:leave-initrd:sysinit:ready \
          --bank=sha256 --bank=sha384 --json=short > $out
      '';
}
