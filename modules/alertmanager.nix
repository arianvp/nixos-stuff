{ config, ... }:
{
  services.prometheus.alertmanager = {
    enable = true;
    configuration = {
      receivers = [
        {
          name = "webhook";
          webhook_configs = [ { url = "https://webhook.site/e26048d0-866a-4722-adda-06c9b65d8f32"; } ];
        }
      ];
      route = {
        group_by = [
          "cluster"
          "alertname"
        ];
        receiver = "webhook";
      };
    };

    /*
      tls_server_config = {
      cert_file = "/run/credentials/alertmanager/svid.0.pem";
      key_file = "/run/credentials/alertmanager/svid.0.key";

      client_auth_type = "RequireAndVerifyClientCert";
      client_ca_file = "/run/credentials/alertmanager/bundle.0.pem";
      };
    */

    # TODO: how to discover these?  mDNS discovery is *NOT* supported by alertmanager
    clusterPeers = [

    ];
  };

  # advertise the service on LAN
  systemd.dnssd.services.alertmanager = {
    type = "_http._tcp";
    port = config.services.prometheus.alertmanager.port;
  };

  # TODO: Both UDP and TCP
  # advertise the cluster address on LAN
  # systemd.dnssd.services.alertmanager-cluster = {
  #  type = "_http._tcp";
  #  port = 9094;
  # };
}
