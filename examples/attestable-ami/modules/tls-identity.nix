# Serves HTTPS with a private key that only an instance running this image
# ever holds.
#
# Nobody generates the key on their own machine: `aws kms
# generate-data-key-pair-without-plaintext` returns its public half, and its
# private half encrypted under the pinned KMS key. A CA certifies the public
# half, and the certificate and the encrypted private half travel in the user
# data. KMS only releases the private half to this image, so whoever trusts
# the CA knows they are talking to this image.
{ lib, pkgs, ... }:
{
  imports = [ ./kms-decrypt.nix ];

  services.kms-decrypt.secrets.tls-key = { };

  # KMS returns the private key as DER, and nginx wants PEM.
  systemd.services.tls-key = {
    description = "Convert the TLS key for nginx";
    requires = [ "kms-decrypt-tls-key.service" ];
    after = [ "kms-decrypt-tls-key.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      LoadCredential = "der:/run/kms-decrypt/tls-key";
      ExecStart = "${lib.getExe pkgs.openssl} pkey -inform DER -in %d/der -out /run/tls-key/key.pem";
      RuntimeDirectory = "tls-key";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = true;
      UMask = "0077";
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.default = {
      default = true;
      onlySSL = true;
      sslCertificate = "/run/credentials/nginx.service/certificate";
      sslCertificateKey = "/run/credentials/nginx.service/key";
      locations."/".return = "200 'served by an attested image\\n'";
    };
  };

  systemd.services.nginx = {
    # Only checks the configuration, which the build already did, and is a
    # shell script.
    preStart = lib.mkForce "";
    requires = [ "tls-key.service" ];
    after = [
      "tls-key.service"
      "systemd-imds-import.service"
    ];
    serviceConfig.LoadCredential = [
      "certificate:tls.certificate"
      "key:/run/tls-key/key.pem"
    ];
  };
}
