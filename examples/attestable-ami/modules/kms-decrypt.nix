# Unwraps secrets that KMS only releases to an instance running this exact
# image: KMS only answers when the request carries a NitroTPM attestation
# document whose PCRs satisfy the key policy.
#
# The ciphertexts arrive as credentials, e.g. from the instance's user data
# through ./imds.nix. User data isn't measured, so it must not pick the key:
# an operator could otherwise start this genuine image against a key and
# ciphertext of their own. The key is a build input instead.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.kms-decrypt;
in
{
  options.services.kms-decrypt = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nitrotpm-tools.overrideAttrs (previousAttrs: {
        pname = "nitro-tpm-kms-decrypt";
        patches = previousAttrs.patches or [ ] ++ [ ./kms-decrypt-ciphertext-file.patch ];
        cargoBuildFlags = [
          "--example"
          "nitro-tpm-kms-decrypt"
        ];
        postInstall = ''
          install -Dm755 target/*/release/examples/nitro-tpm-kms-decrypt -t $out/bin
        '';
        meta = previousAttrs.meta // {
          mainProgram = "nitro-tpm-kms-decrypt";
        };
      });
      defaultText = lib.literalMD "the `nitro-tpm-kms-decrypt` example of `pkgs.nitrotpm-tools`";
      description = "Package providing `nitro-tpm-kms-decrypt`.";
    };

    keyId = lib.mkOption {
      type = lib.types.str;
      example = "arn:aws:kms:eu-central-1:111122223333:key/1234abcd-12ab-34cd-56ef-1234567890ab";
      description = "The KMS key the secrets are encrypted with.";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options.credential = lib.mkOption {
              type = lib.types.str;
              default = "kms.${name}";
              description = "Credential holding the base64 encoded output of `aws kms encrypt`.";
            };
          }
        )
      );
      default = { };
      description = ''
        Secrets to decrypt to {file}`/run/kms-decrypt/<name>`, from which other
        units load them with `LoadCredential=`.
      '';
    };
  };

  config = lib.mkIf (cfg.secrets != { }) {
    # Not RuntimeDirectory=, which is created only after StandardOutput= is
    # opened.
    systemd.tmpfiles.settings.kms-decrypt."/run/kms-decrypt".d.mode = "0700";

    systemd.services = lib.mapAttrs' (
      name: secret:
      lib.nameValuePair "kms-decrypt-${name}" {
        description = "Decrypt ${name} with an attested KMS request";
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [
          "network-online.target"
          "tpm2.target"
          "systemd-imds-import.service"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          LoadCredential = "ciphertext:${secret.credential}";
          ExecStart = "${lib.getExe cfg.package} --key-id ${cfg.keyId} --ciphertext-file %d/ciphertext";
          StandardOutput = "truncate:/run/kms-decrypt/${name}";
          # Why KMS refused, on the console of an instance nobody can log in to.
          StandardError = "journal+console";
          UMask = "0077";
        };
      }
    ) cfg.secrets;
  };
}
