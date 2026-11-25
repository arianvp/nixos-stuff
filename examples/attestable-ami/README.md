# Attestable AMI

An [attestable AMI](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/attestable-ami.html)
built from nixpkgs alone, following
[aws/nitrotpm-attestation-samples](https://github.com/aws/nitrotpm-attestation-samples/tree/main/nix).

`configuration.nix` puts the appliance together from modules that each do one
thing. Most of them have nothing to do with AWS:

- `modules/appliance.nix`: a sealed system. It uses the `bashless` profile, so
  there is no shell to log in to, and its root is a tmpfs.
- `modules/verity-store.nix`: puts the Nix store on its own partitions as
  erofs under dm-verity, with the verity root hash on the kernel command line,
  so that measuring the command line covers the entire system.
- `modules/single-uki.nix`: an image module, registered as
  `image.modules.attestable-ami`, that adds an ESP holding a single UKI that
  the firmware boots directly, and measures into PCR4.
- `modules/secure-boot.nix`: Secure Boot without a signing key. db holds the
  UKI's Authenticode hash, so the firmware boots exactly this UKI, and the
  platform key is a certificate nobody has the private key of, so nobody can
  change db. It builds the UEFI variable store the AMI is registered with.
- `modules/boot-state.nix`: prints the measured PCRs and the kernel's security
  state to the console.

And the AWS specifics:

- `modules/ec2.nix`: serial console and EBS settings.
- `modules/nitrotpm.nix`: `system.build.pcrs`, the PCR values NitroTPM will
  report, computed by `nitro-tpm-pcr-compute` from the UKI and the UEFI
  variables. A patch teaches it that firmware measures a db entry that allowed
  an image by its hash, not just by a certificate.
- `create-ami.nix`: uploads the image with coldsnap and registers it with
  NitroTPM support and the UEFI variable store.

`test.nix` boots the image under OVMF with a software TPM and the same UEFI
variables, and checks that the firmware measured exactly the predicted PCR
values, and that it refuses to boot a UKI that differs in nothing but its
command line.

## Usage

```console
$ nix build .#pcrs && cat result
$ nix flake check            # boot the image and compare the measured PCRs
$ nix run .#create-ami       # upload with coldsnap, register with NitroTPM; prints the AMI ID
```

Lock a KMS key to the image by adding conditions on the values from
`nix build .#pcrs` to the key policy statement that allows `kms:Decrypt`:

```json
"Condition": {
  "StringEqualsIgnoreCase": {
    "kms:RecipientAttestation:NitroTPMPCR4": "<PCR4>",
    "kms:RecipientAttestation:NitroTPMPCR7": "<PCR7>",
    "kms:RecipientAttestation:NitroTPMPCR12": "<PCR12>"
  }
}
```

PCR4 pins the UKI, and with it the entire system. PCR7 pins the Secure Boot
variables, i.e. that only this UKI can boot at all. With Secure Boot on,
systemd-stub ignores command lines that boot entries pass it
([GHSA-xrv8-2pf5-f3q7](https://github.com/aws/nitrotpm-attestation-samples/security/advisories/GHSA-xrv8-2pf5-f3q7)),
and PCR12 records anything else it was given. All zeros means nothing.

The serial console (`aws ec2 get-console-output`) shows the PCRs the instance
actually measured, for comparison with the key policy.
