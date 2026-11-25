# Uploads the image straight into an EBS snapshot (no instance or S3 bucket
# involved) and registers it as a NitroTPM-enabled AMI. Prints the AMI ID.
{
  writeShellApplication,
  awscli2,
  coldsnap,
  image,
}:
let
  inherit (image.passthru) config;
  name = "${config.image.baseName}-${builtins.substring 0 32 (baseNameOf image)}";
in
writeShellApplication {
  name = "create-ami";
  runtimeInputs = [
    awscli2
    coldsnap
  ];
  text = ''
    snapshot=$(coldsnap upload --wait --omit-zero-blocks ${image}/${image.passthru.filePath})

    aws ec2 register-image \
      --name ${name} \
      --architecture ${config.nixpkgs.hostPlatform.linuxArch} \
      --boot-mode uefi \
      --tpm-support v2.0 \
      --ena-support \
      --virtualization-type hvm \
      --root-device-name /dev/xvda \
      --block-device-mappings "DeviceName=/dev/xvda,Ebs={SnapshotId=$snapshot}" \
      --query ImageId --output text
  '';
  meta.description = "Upload ${config.image.baseName} as an attestable AMI";
}
