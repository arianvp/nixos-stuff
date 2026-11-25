# Boots the image, byte for byte as it would be uploaded, on OVMF with a
# software TPM, and checks that the firmware measures exactly what
# nitro-tpm-pcr-compute predicted.
{
  appliance,
  predict-pcr12,
  hostPkgs,
  lib,
  ...
}:
let
  image = appliance.config.system.build.images.attestable-ami;

  # A CA, and a certificate for a key whose private half the CA never sees,
  # like one from `aws kms generate-data-key-pair-without-plaintext`.
  pki = hostPkgs.runCommand "pki" { nativeBuildInputs = [ hostPkgs.openssl ]; } ''
    mkdir $out && cd $out
    openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -outform DER -out key.der
    openssl pkey -inform DER -in key.der -pubout -out key.pub
    openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes \
      -keyout ca.key -out ca.pem -subj /CN=ca -days 1
    echo subjectAltName=IP:192.168.1.10 > extensions
    openssl x509 -new -force_pubkey key.pub -subj /CN=appliance \
      -extfile extensions -CA ca.pem -CAkey ca.key -days 1 -out cert.pem
  '';

  userData = hostPkgs.runCommand "user-data" { nativeBuildInputs = [ hostPkgs.jq ]; } ''
    jq --null-input --join-output --rawfile certificate ${pki}/cert.pem '{"systemd.credentials": [
      {name: "kms.example", text: "Y2lwaGVydGV4dA=="},
      {name: "kms.tls-key", text: "Y2lwaGVydGV4dA=="},
      {name: "tls.certificate", text: $certificate}
    ]}' > $out
  '';

  # Variants that report what they received from the user data, that try to
  # run a copy of a store binary from the tmpfs root, which the IPE policy must
  # refuse unless IPE is permissive, and that get their TLS key from ./pki
  # instead of KMS, which needs a NitroTPM.
  probe =
    kernelParams:
    (appliance.extendModules {
      modules = [
        (
          { lib, pkgs, ... }:
          {
            boot.kernelParams = kernelParams;
            systemd.services.kms-decrypt-tls-key.serviceConfig.ExecStart =
              lib.mkForce "${pkgs.coreutils}/bin/cat ${pki}/key.der";
            systemd.services.show-credential = {
              description = "Print the credential imported from the user data";
              wantedBy = [ "multi-user.target" ];
              after = [ "systemd-imds-import.service" ];
              before = [ "ipe-disable.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${lib.getExe pkgs.gnugrep} --with-filename . /run/credstore/kms.example";
                StandardOutput = "journal+console";
              };
            };
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

  node =
    { lib, ... }:
    {
      virtualisation = {
        directBoot.enable = false;
        mountHostNixStore = false;
        useEFIBoot = true;
        tpm.enable = true;
        # Only the test network, where ./imds is.
        qemu.networkingOptions = lib.mkForce [ ];
        # What systemd's hwdb recognizes EC2 by.
        qemu.options = [ "-smbios type=0,vendor=AmazonEC2" ];
      };
    };

  # Stands in for EC2's DHCP and IMDSv2, serving `userData`, and talks TLS to
  # the enforcing variant at 192.168.1.10.
  imds =
    { nodes, pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.curl ];
      networking.firewall.enable = false;
      networking.interfaces.eth1.ipv4.addresses = lib.mkForce [
        {
          address = "192.168.1.254";
          prefixLength = 24;
        }
        {
          address = "169.254.169.254";
          prefixLength = 32;
        }
      ];
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          port = 0;
          interface = "eth1";
          dhcp-range = "192.168.1.100,192.168.1.200";
          dhcp-option = "option:router,192.168.1.254";
          # The MAC the test driver gives the enforcing variant.
          dhcp-host = "52:54:00:12:01:${
            lib.fixedWidthString 2 "0" (lib.toHexString nodes.enforcing.virtualisation.test.nodeNumber)
          },192.168.1.10";
        };
      };
      systemd.services.imds = {
        wantedBy = [ "multi-user.target" ];
        serviceConfig.ExecStart = pkgs.writers.writePython3 "imds" { flakeIgnore = [ "E501" ]; } ''
          import http.server

          TOKEN = b"token"
          USER_DATA = open("${userData}", "rb").read()


          class Handler(http.server.BaseHTTPRequestHandler):
              def reply(self, body):
                  self.send_response(200)
                  self.send_header("Content-Length", str(len(body)))
                  self.end_headers()
                  self.wfile.write(body)

              def do_PUT(self):
                  if self.path == "/latest/api/token":
                      self.reply(TOKEN)
                  else:
                      self.send_error(404)

              def do_GET(self):
                  token = self.headers.get("X-aws-ec2-metadata-token")
                  if self.path == "/latest/user-data" and token == "token":
                      self.reply(USER_DATA)
                  else:
                      self.send_error(404)


          http.server.ThreadingHTTPServer(("", 80), Handler).serve_forever()
        '';
      };
    };
in
{
  name = "attestable-ami-measured-boot";

  globalTimeout = 300;

  # The nodes only provide the QEMU invocation; they boot the image's UKI from
  # the disk rather than a system of their own.
  nodes = {
    inherit imds;
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

      # The firmware leaves PCR 12 alone, but systemd measures the user data
      # into it.
      expected["PCR12"] = subprocess.run(
          ["${predict-pcr12}/bin/predict-pcr12", "${userData}"],
          check=True, capture_output=True, text=True,
      ).stdout.strip()

      imds.start()
      imds.wait_for_unit("imds.service")
      imds.wait_for_unit("dnsmasq.service")

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

      with subtest("Credentials arrive through the user data"):
          enforcing.wait_for_console_text(
              r"/run/credstore/kms.example:Y2lwaGVydGV4dA==", timeout=timedelta(minutes=2)
          )

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

      with subtest("The image serves TLS with the key the CA certified"):
          imds.wait_until_succeeds(
              "curl --fail --silent --cacert ${pki}/ca.pem https://192.168.1.10/"
              " | grep 'served by an attested image'",
              timeout=60,
          )
    '';
}
