# Boots the image, byte for byte as it would be uploaded, on OVMF with a
# software TPM, and checks that the firmware measures exactly what
# nitro-tpm-pcr-compute predicted.
{ appliance, ... }:
let
  image = appliance.config.system.build.images.attestable-ami;

  node = {
    virtualisation = {
      directBoot.enable = false;
      mountHostNixStore = false;
      useEFIBoot = true;
      tpm.enable = true;
    };
  };
in
{
  name = "attestable-ami-measured-boot";

  globalTimeout = 300;

  # The nodes only provide the QEMU invocation; they boot the image's UKI from
  # the disk rather than a system of their own.
  nodes.machine = node;

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

      for pcr in (4, 7, 11, 12):
          with subtest(f"PCR{pcr} matches the prediction"):
              machine.wait_for_console_text(
                  rf"(?i)pcr-sha384/{pcr}:{expected[f'PCR{pcr}']}", timeout=timedelta(minutes=2)
              )
    '';
}
