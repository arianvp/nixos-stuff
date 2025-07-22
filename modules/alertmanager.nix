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
    clusterPeers = [

    ];
  };

  # advertise the service on LAN
  systemd.dnssd.services.alertmanager = {
    type = "_http._tcp";
    port = config.services.prometheus.alertmanager.port;
  };

  # advertise the cluster address on LAN
  systemd.dnssd.services.alertmanager-cluster = {
    type = "_http._tcp";
    port = 9094;
  };
}
