{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.virtualisation.tpm.provisioningRootCA;

  ek_config = pkgs.writeText "ek-sign.cnf" ''
    [ tpm_policy ]
    basicConstraints = critical, CA:FALSE

    keyUsage = critical, keyEncipherment
    certificatePolicies = 2.23.133.2.1
    extendedKeyUsage = 2.23.133.8.1

    subjectAltName = ASN1:SEQUENCE:dirname_tpm

    [ dirname_tpm ]
    seq = EXPLICIT:4,SEQUENCE:dirname_tpm_seq

    [ dirname_tpm_seq ]
    set = SET:dirname_tpm_set

    [ dirname_tpm_set ]
    seq.1 = SEQUENCE:dirname_tpm_seq_manufacturer
    seq.2 = SEQUENCE:dirname_tpm_seq_model
    seq.3 = SEQUENCE:dirname_tpm_seq_version

    # Mock STM TPM
    [dirname_tpm_seq_manufacturer]
    oid = OID:2.23.133.2.1
    str = UTF8:"id:53544D20"

    [dirname_tpm_seq_model]
    oid = OID:2.23.133.2.2
    str = UTF8:"ST33HTPHAHD4"

    [dirname_tpm_seq_version]
    oid = OID:2.23.133.2.3
    str = UTF8:"id:00010101"
  '';
in
{
  options.virtualisation.tpm.provisioningRootCA = {
    enable = lib.mkEnableOption "TPM EKCert provisioning with a root CA";
    key = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the CA private key for signing EKCerts";
    };
    certificate = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to the CA certificate";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.key != null;
        message = "virtualisation.tpm.provisioningRootCA.key must be set when enable is true";
      }
      {
        assertion = cfg.certificate != null;
        message = "virtualisation.tpm.provisioningRootCA.certificate must be set when enable is true";
      }
    ];

    virtualisation.tpm = {
      enable = true;
      provisioning = ''
        export PATH=${
          lib.makeBinPath [
            pkgs.openssl
            pkgs.tpm2-tools
          ]
        }:$PATH

        tpm2_createek -G rsa -u ek.pub -c ek.ctx -f pem

        # Sign a certificate with the provisioning CA
        openssl x509 \
          -extfile ${ek_config} \
          -new -days 365 \
          -subj "/CN=swtpm-ekcert" \
          -extensions tpm_policy \
          -CA ${cfg.certificate} -CAkey ${cfg.key} \
          -out ekcert.der -outform der \
          -force_pubkey ek.pub

        # Create NVRAM slot for the certificate
        tpm2_nvdefine 0x01c00002 \
          -C o \
          -a "ownerread|policyread|policywrite|ownerwrite|authread|authwrite" \
          -s "$(wc -c ekcert.der | cut -f 1 -d ' ')"

        tpm2_nvwrite 0x01c00002 -C o -i ekcert.der
      '';
    };

    systemd.tmpfiles.settings.tpm2-tss-fapi = {
      "/sys/kernel/security/tpm[0-9]/binary_bios_measurements"."z-" = {
        mode = "0440";
        user = "root";
        group = config.security.tpm2.tssGroup;
      };
      "/sys/kernel/security/ima/binary_runtime_measurements"."z-" = {
        mode = "0440";
        user = "root";
        group = config.security.tpm2.tssGroup;
      };
    };
  };
}
