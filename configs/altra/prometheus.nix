{ lib, pkgs, ... }:
{

  systemd.services.prometheus.serviceConfig.ExecStartPre =
    "${lib.getExe' pkgs.spire "spire-agent"} api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write $RUNTIME_DIRECTORY";
  services.prometheus = {
    enable = true;
    listenAddress = "[::]";
    webConfigFile = (pkgs.formats.yaml { }).generate "config.yml" {
      tls_server_config = {
        cert_file = "/run/prometheus/svid.0.pem";
        key_file = "/run/prometheus/svid.0.key";
      };
    };
  };
}
