{
  services.nginx.enable = true;
  services.nginx.virtualHosts."nixos.sh" = {
    listen = [
      {
        addr = "2a05:2d01:2025:f000:dead:beef:cafe:babe";
        port = 443;
        ssl = true;
      }
    ];
    addSSL = true;
    enableACME = true;
    root = ./.;
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "letsencrypt@arianvp.me";
  };
}
