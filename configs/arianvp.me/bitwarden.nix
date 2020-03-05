{
  services.nginx = {
    virtualHosts = {
      "techstock.photos" = {
        forceSSL = true;
        enableACME = true;
        locations = {
          "/".proxyPass = "http://localhost:8000";
          "/notifications/hub".extraConfig = ''
            proxy_pass http://localhost:3012;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
          "/notifications/hub/negotiate".extraConfig =
            ''
              proxy_pass http://localhost:8000;
            '';
        };
      };
    };
  };

  services.bitwarden_rs = {
    enable = true;
    config = {
      domain = https://techstock.photos;
    };
  };
}
