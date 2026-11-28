# Boots the image, byte for byte as it would be uploaded, on OVMF with a
# software TPM and the image's Secure Boot variables, and checks that the
# firmware measures exactly what nitro-tpm-pcr-compute predicted, and that it
# refuses to boot any other UKI.
{ appliance, hostPkgs, ... }:
let
  image = appliance.config.system.build.images.attestable-ami;
  inherit (image.passthru.config.system.build) secureBoot;

  # A variant whose UKI differs in nothing but its command line.
  tampered =
    (appliance.extendModules { modules = [ { boot.kernelParams = [ "tampered" ]; } ]; })
    .config.system.build.images.attestable-ami;

  # The same variables as the AMI's, in OVMF's variable store.
  variables =
    hostPkgs.runCommand "secure-boot-vars.fd"
      { nativeBuildInputs = [ hostPkgs.python3Packages.virt-firmware ]; }
      ''
        owner=$(cat ${secureBoot}/owner)
        virt-fw-vars --input ${hostPkgs.OVMFFull.variables} \
          --set-pk $owner ${secureBoot}/PK.cer \
          --add-db-hash $owner "$(cat ${secureBoot}/uki.sha256)" \
          --no-microsoft --secure-boot --output $out
      '';

  node = {
    virtualisation = {
      directBoot.enable = false;
      mountHostNixStore = false;
      useEFIBoot = true;
      efi.variables = variables;
      tpm.enable = true;
    };
  };
in
{
  name = "attestable-ami-measured-boot";

  globalTimeout = 300;

  # The nodes only provide the QEMU invocation; they boot the image's UKI from
  # the disk rather than a system of their own.
  nodes = {
    machine = node;
    tampered = node;
  };

  testScript =
    { nodes, ... }:
    ''
      import json
      from datetime import timedelta
      import os
      import subprocess
      import tempfile

      disks = []

      def boot(machine, image):
          disk = tempfile.NamedTemporaryFile()
          subprocess.run([
              "${nodes.machine.virtualisation.qemu.package}/bin/qemu-img",
              "create", "-f", "qcow2", "-F", "raw", "-b", image, disk.name,
          ], check=True)
          os.environ["NIX_DISK_IMAGE"] = disk.name
          machine.start(allow_reboot=False)
          disks.append(disk)

      with open("${image.passthru.config.system.build.pcrs}") as f:
          expected = json.load(f)["Measurements"]

      boot(machine, "${image}/${image.passthru.filePath}")
      boot(tampered, "${tampered}/${tampered.passthru.filePath}")

      for pcr in (4, 7, 12):
          with subtest(f"PCR{pcr} matches the prediction"):
              machine.wait_for_console_text(
                  rf"(?i)pcr-sha384/{pcr}:{expected[f'PCR{pcr}']}", timeout=timedelta(minutes=2)
              )

      with subtest("Secure Boot refuses any other UKI"):
          tampered.wait_for_console_text("Access Denied", timeout=timedelta(minutes=2))
    '';
}
