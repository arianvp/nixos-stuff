# Boots the image, byte for byte as it would be uploaded, on OVMF with a
# software TPM, and checks that the firmware measures exactly what
# nitro-tpm-pcr-compute predicted.
{ appliance, ... }:
let
  image = appliance.config.system.build.images.attestable-ami;

  # Variants that try to run a copy of a store binary from the tmpfs root,
  # which the IPE policy must refuse unless IPE is permissive.
  probe =
    kernelParams:
    (appliance.extendModules {
      modules = [
        (
          { pkgs, ... }:
          {
            boot.kernelParams = kernelParams;
            systemd.services.ipe-probe = {
              description = "Run a binary from outside the store";
              wantedBy = [ "multi-user.target" ];
              after = [ "log-boot-state.service" ];
              serviceConfig = {
                Type = "oneshot";
                StateDirectory = "ipe-probe";
                ExecStartPre = "${pkgs.coreutils}/bin/cp ${pkgs.coreutils}/bin/true /var/lib/ipe-probe/true";
                ExecStart = "/var/lib/ipe-probe/true";
              };
            };
            systemd.services.ipe-disable = {
              description = "Switch IPE to permissive";
              wantedBy = [ "multi-user.target" ];
              before = [ "log-boot-state.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.coreutils}/bin/echo 0";
                StandardOutput = "file:/sys/kernel/security/ipe/enforce";
              };
            };
          }
        )
      ];
    }).config.system.build.images.attestable-ami;
  enforcing = probe [ ];
  permissive = probe [ "ipe.enforce=0" ];

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
  nodes = {
    machine = node;
    enforcing = node;
    permissive = node;
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
      boot(enforcing, "${enforcing}/${enforcing.passthru.filePath}")
      boot(permissive, "${permissive}/${permissive.passthru.filePath}")

      for pcr in (4, 7, 12):
          with subtest(f"PCR{pcr} matches the prediction"):
              machine.wait_for_console_text(
                  rf"(?i)pcr-sha384/{pcr}:{expected[f'PCR{pcr}']}", timeout=timedelta(minutes=2)
              )

      # Getting this far means the initrd loaded dm_verity under lockdown.
      with subtest("The kernel is locked down"):
          machine.wait_for_console_text(r"lockdown:.*\[confidentiality\]")

      # Getting this far means everything the system ran so far was allowed.
      with subtest("IPE enforces the policy"):
          machine.wait_for_console_text(r"ipe/enforce:1")
          machine.wait_for_console_text(r"ipe/policies/nixos/active:1")

      with subtest("Not even root can switch IPE to permissive"):
          enforcing.wait_for_console_text(
              r"Failed to start .*Switch IPE to permissive", timeout=timedelta(minutes=2)
          )
          enforcing.wait_for_console_text(r"ipe/enforce:1")

      with subtest("IPE refuses to run code from outside the store"):
          enforcing.wait_for_console_text(r"Failed to start .*Run a binary from outside the store")
          permissive.wait_for_console_text(
              r"Finished .*Run a binary from outside the store", timeout=timedelta(minutes=2)
          )
    '';
}
