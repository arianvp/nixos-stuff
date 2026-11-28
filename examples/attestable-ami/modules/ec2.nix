# What a NixOS image needs on EC2 Nitro instances beyond what NixOS already
# does by default.
{
  # `aws ec2 get-console-output` reads the first serial port.
  boot.kernelParams = [
    "console=ttyS0,115200n8"
    # https://docs.aws.amazon.com/ebs/latest/userguide/nvme-ebs-volumes.html#timeout-nvme-ebs-volumes
    "nvme_core.io_timeout=4294967295"
  ];
}
