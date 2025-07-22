{ config, ... }:
{
  services.grafana = {
    enable = true;
    settings = {
      server.http_addr = "";
      server.domain = "${config.networking.hostName}.local";
    };
    provision.enable = true;
    provision.datasources = {
      settings.deleteDatasources = [
        /*
          {
            name = "AlertManager";
            orgId = 1;
          }
        */
      ];
      /*
        settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          # TODO: SD
          url = "http://localhost:${toString config.services.prometheus.port}";
        }
        {
          name = "AlertManager";
          type = "alertmanager";
          jsonData.implementation = "prometheus";
          jsonData.handleGrafanaManagedAlerts = true;
          # TODO: SD
          url = "http://localhost:${toString config.services.prometheus.alertmanager.port}";
        }
        ];
      */
    };
  };
}
