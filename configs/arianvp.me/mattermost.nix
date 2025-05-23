{
  environment.systemPackages = [ pkgs.mattermost ];
  services.mattermost = {
    enable = true;
    siteUrl = "https://mattermost.arianvp.me";
    listenAddress = "127.0.0.1:8085";
  };
  services.nginx = {
    upstreams."mattermost".servers = {
      "${config.services.mattermost.listenAddress}" = { };
    };
    virtualHosts = {
      "mattermost.arianvp.me" = {
        forceSSL = true;
        enableACME = true;
        locations."~ /api/v[0-9]+/(users/)?websocket$" = {
          extraConfig = ''
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            client_max_body_size 50M;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Frame-Options SAMEORIGIN;
            proxy_buffers 256 16k;
            proxy_buffer_size 16k;
            client_body_timeout 60;
            send_timeout 300;
            lingering_timeout 5;
            proxy_connect_timeout 90;
            proxy_send_timeout 300;
            proxy_read_timeout 90s;
            proxy_pass http://mattermost;
          '';
        };
        locations."/" = {
          extraConfig = ''
            client_max_body_size 50M;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Frame-Options SAMEORIGIN;
            proxy_buffers 256 16k;
            proxy_buffer_size 16k;
            proxy_read_timeout 600s;
            proxy_http_version 1.1;
            proxy_pass http://mattermost;
          '';
        };
      };
    };
  };
}
