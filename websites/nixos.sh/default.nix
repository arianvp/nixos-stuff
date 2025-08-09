{
  services.nginx.enable = true;
  services.nginx.virtualHosts."nixos.sh" = {
    addSSL = true;
    enableACME = true;
    root = ./.;
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "letsencrypt@arianvp.me";
  };
}
