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
- `modules/kernel-certificates.nix`: a kernel that only trusts this system's
  own kernel modules, without giving up reproducibility.
- `modules/lockdown.nix`: kernel lockdown, so not even root can modify or read
  the running kernel.
- `modules/ipe.nix`: an IPE policy, added to the image module, that only lets
  the kernel run code from the initramfs and the verity store. A binary
  written anywhere else never runs, not even as root, and nothing can switch
  IPE off.
- `modules/boot-state.nix`: prints the measured PCRs and the kernel's security
  state to the console.

And the AWS specifics:

- `modules/ec2.nix`: serial console and EBS settings.
- `modules/imds.nix`: systemd's IMDS support, which imports credentials from
  the instance's user data, and measures the user data into PCR12 first.
- `modules/nitrotpm.nix`: `system.build.pcrs`, the PCR values NitroTPM will
  report, computed by `nitro-tpm-pcr-compute` from the UKI.
- `predict-pcr12.nix`: the PCR12 value for a given user data file.
- `modules/kms-decrypt.nix`: decrypts secrets from the user data with a KMS
  key pinned in `kms-key-arn.txt`. KMS only releases them to an instance that
  presents the PCR values of this image and this user data.
- `modules/tls-identity.nix`: serves HTTPS with a private key that only an
  instance running this image ever holds.
- `create-ami.nix`: uploads the image with coldsnap and registers it with
  NitroTPM support.

`test.nix` boots the image under OVMF with a software TPM and a stand-in for
IMDS, and checks that the firmware and systemd measured exactly the predicted
PCR values, that credentials arrive through the user data, that lockdown and
IPE are enforced, that IPE refuses a binary copied out of the store, and that
the image serves TLS with the certified key. Only the KMS requests themselves
need a real NitroTPM.

## Usage

```console
$ nix build .#pcrs && cat result
$ nix flake check            # boot the image and compare the measured PCRs
$ nix run .#create-ami       # upload with coldsnap, register with NitroTPM; prints the AMI ID
```

The serial console (`aws ec2 get-console-output`) shows the PCRs the instance
actually measured, for comparison with the key policy.

`nix run .#e2e` tests the examples end to end on EC2 with the AWS credentials
in the environment: it creates a KMS key that only the image can decrypt
with, uploads the image, and checks that the instance measures the predicted
PCRs, that KMS releases a secret and a TLS key to it but not to the same image
with other user data, and, where the flake has them, that Secure Boot refuses
any other UKI and that a parent spawns a Nitro Sandbox. It removes everything
it created again, except for the key, which KMS deletes after 7 days.
`KEEP=1` keeps everything for inspection.

## Bringing a secret

The user data isn't part of the image, so whoever launches the AMI chooses it.
It must therefore not choose the KMS key: the operator could start this
genuine image against a key and ciphertext of their own. The key's ARN is a
build input instead, which means the key comes first:

1. Create the key with a policy that lets you encrypt and change its policy,
   but not decrypt, and put its ARN in `kms-key-arn.txt`.
2. Encrypt the secret into the user data, as a credential named `kms.<name>`
   for each of `services.kms-decrypt.secrets`:

   ```console
   $ aws kms encrypt --key-id "$(cat kms-key-arn.txt)" --plaintext fileb://secret \
       --query CiphertextBlob --output text \
     | jq -R '{"systemd.credentials": [{name: "kms.example", text: .}]}' > user-data.json
   ```

3. Allow `kms:Decrypt` only for this image and this user data:

   ```console
   $ nix build .#pcrs && cat result
   $ nix run .#predict-pcr12 -- user-data.json
   ```

   ```json
   "Condition": {
     "StringEqualsIgnoreCase": {
       "kms:RecipientAttestation:NitroTPMPCR4": "<PCR4>",
       "kms:RecipientAttestation:NitroTPMPCR7": "<PCR7>",
       "kms:RecipientAttestation:NitroTPMPCR12": "<PCR12>"
     }
   }
   ```

4. Launch the AMI with `--user-data file://user-data.json`. The secret ends up
   in `/run/kms-decrypt/example`, from where services load it with
   `LoadCredential=`.

PCR12 must be bound: with Secure Boot off, systemd-stub accepts a command line
from the boot entry and measures it into PCR12
([GHSA-xrv8-2pf5-f3q7](https://github.com/aws/nitrotpm-attestation-samples/security/advisories/GHSA-xrv8-2pf5-f3q7)),
and systemd measures the user data into it before importing credentials from
it. Binding PCR12 therefore binds the exact user data as well, and changing
the user data means updating the policy.

## A TLS identity only the image holds

KMS can't sign on behalf of an attested instance, but it can create a key pair
whose private half nobody sees except an attested instance:

1. Have KMS create the key pair. You get the public key, and the private key
   encrypted under the pinned key:

   ```console
   $ aws kms generate-data-key-pair-without-plaintext --key-id "$(cat kms-key-arn.txt)" \
       --key-pair-spec ECC_NIST_P256 > key-pair.json
   $ jq -r .PublicKey key-pair.json | base64 -d | openssl pkey -pubin -inform DER -out key.pub
   ```

2. Certify the public key with your CA. There is no CSR, as nobody can sign
   one:

   ```console
   $ echo subjectAltName=DNS:appliance.example.com > extensions
   $ openssl x509 -new -force_pubkey key.pub -subj /CN=appliance.example.com \
       -extfile extensions -CA ca.pem -CAkey ca.key -out cert.pem
   ```

3. Put the encrypted private key and the certificate in the user data, next to
   any other secrets, then bind the key policy to it as above:

   ```console
   $ jq -n --rawfile certificate cert.pem --slurpfile pair key-pair.json \
       '{"systemd.credentials": [
          {name: "kms.tls-key", text: $pair[0].PrivateKeyCiphertextBlob},
          {name: "tls.certificate", text: $certificate}
        ]}' > user-data.json
   ```

The image decrypts the private key at boot, and nginx serves HTTPS with it.
Clients only need to trust your CA: it certified a key that KMS only releases
to this image, so whoever answers with it runs this image.
