{ lib, pkgs, ... }:
{
  networking.firewall.allowedTCPPorts = [ 9090 ];
  spire.controllerManager.staticEntries.prometheus = {
    parentID = "spiffe://nixos.sh/server/altra";
    spiffeID = "spiffe://nixos.sh/server/prometheus";
    selectors = [ "systemd:id:prometheus.service" ];
  };
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
