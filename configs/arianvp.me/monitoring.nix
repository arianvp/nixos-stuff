{ ... }:
let
  dashboards = null;
in
{
  services = {
    netdata = {
      enable = true;
    };
    loki = {
      enable = false;
      configuration = {
        auth_enabled = false;
        server.http_listen_port = 3100;
      };
    };
    prometheus = {
      enable = true;
      scrapeConfigs = [ { job_name = "local"; static_configs = [ {
        targets = [ "localhost:9100" ];
      } ]; } ];
      exporters.node = {
        enable = true;
      };
    };
    grafana = {
      enable = true;
      analytics.reporting.enable = false;
      provision.enable = true;
      provision.datasources = [
        {
          name = "prometheus"; # name is mandatory but I can leave it out
          editable = false;
          type = "prometheus";
          url = "http://127.0.0.1:9090"; # TODO make configurable
        }
      ];


      # TODO grafana should be provisioned through a NixOS module
      /*provision = {
        datasources =         dashboards = [
          {
            name = "NixOS generated provider";
            folder = "NiXOS generated provider";
            disableDeletion = true;
            # editable = false; Not supported :/
            options.path = "${dashboards}";
          };
        ];
      };
      */
    };
  };
}
