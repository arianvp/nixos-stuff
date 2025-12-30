{
  lib,
  pkgs,
  config,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/digital-ocean-config.nix")
    ./network.nix
    ../modules/sshd.nix
  ];

  system.stateVersion = "25.05";

  # needed for networkd to function. obscure
  time.timeZone = "Europe/Amsterdam";

  # Weechat
  networking.firewall.allowedTCPPorts = [
    80 # http
    443 # https
  ];

  services.nginx = {
    enable = true;
    commonHttpConfig = ''
      # Add HSTS header with preloading to HTTPS requests.
      # Adding this header to HTTP requests is discouraged
      map $scheme $hsts_header {
          https   "max-age=31536000; includeSubdomains; preload";
      }
      add_header Strict-Transport-Security $hsts_header always;

      # Enable CSP for your services.
      #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

      # Minimize information leaked to other domains
      add_header 'Referrer-Policy' 'origin-when-cross-origin' always;

      # Disable embedding as a frame
      add_header X-Frame-Options DENY always;

      # Prevent injection of code in other mime types (XSS Attacks)
      add_header X-Content-Type-Options nosniff always;

      # Enable XSS protection of the browser.
      # May be unnecessary when CSP is configured properly (see above)
      add_header X-XSS-Protection "1; mode=block" always;

    '';
    virtualHosts = {
      "arianvp.me" = {
        forceSSL = true;
        enableACME = true;
        locations."/".root = ../../website;
      };
    };
  };

  # Needed to accept terms
  security.acme.defaults.email = "arian.vanputten@gmail.com";
  security.acme.acceptTerms = true;

  nixpkgs.hostPlatform = {
    system = "x86_64-linux";
  };

}
