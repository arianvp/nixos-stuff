{ config, lib, pkgs, ... }:
  {
    config = {
      /*services.nginx.virtualHosts."prometheus.arianvp.me" = {
        forceSSL = true;
        enableACME = true;
        locations."/".proxyPass = config.services.prometheus.listenAddress;
      };*/
      services.prometheus = {
        enable = true;
        scrapeConfigs = [
          {
            job_name = "static";
            static_configs = [
              {
                targets = [
                  "localhost:${toString (config.services.prometheus.exporters.node.port)}"
                ];
              }
            ];
          }
        ];
        exporters.node.enable = true;
        rules = [
          ''
            ALERT DiskFullInTwoDays 
            IF (predict_linear(node_filesystem_free[1d], 3600*24*2) < 0) 
            FOR 5m
            ANNOTATIONS {
              summary = "Dun Goofed"
            }
            
          ''
        ];
      };
    };
  }
