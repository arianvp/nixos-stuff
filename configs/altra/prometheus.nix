{ lib, pkgs, ... }:
{

  systemd.services.prometheus.serviceConfig.ExecStartPre =
    "${lib.getExe' pkgs.spire "spire-agent"} api fetch x509 -socketPath $SPIFFE_ENDPOINT_SOCKET -write $RUNTIME_DIRECTORY";

  spire.controllerManager.staticEntries = {
    prometheus.spec = {
      parentID = "spiffe://nixos.sh/server/altra";
      spiffeID = "spiffe://nixos.sh/service/prometheus";
      dnsNames = [ "prometheus.altra.nixos.sh" ];
      selectors = [ "systemd:id:prometheus.service" ];
    };
    alertmanager.spec = {
      parentID = "spiffe://nixos.sh/server/altra";
      spiffeID = "spiffe://nixos.sh/service/alertmanager";
      dnsNames = [ "alertmanager.altra.nixos.sh" ];
      selectors = [ "systemd:id:alertmanager.service" ];
    };
  };

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
