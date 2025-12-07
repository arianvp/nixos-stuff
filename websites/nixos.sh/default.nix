{
  services.nginx.enable = true;
  services.nginx.appendHttpConfig = ''
    # Add HSTS header with preloading to HTTPS requests.
    # Adding this header to HTTP requests is discouraged
    map $scheme $hsts_header {
        https   "max-age=31536000; includeSubdomains; preload";
    }
    add_header Strict-Transport-Security $hsts_header;

    # Enable CSP for your services.
    #add_header Content-Security-Policy "script-src 'self'; object-src 'none'; base-uri 'none';" always;

    # Minimize information leaked to other domains
    add_header 'Referrer-Policy' 'origin-when-cross-origin';

    # Disable embedding as a frame
    add_header X-Frame-Options DENY;

    # Prevent injection of code in other mime types (XSS Attacks)
    add_header X-Content-Type-Options nosniff;

    # This might create errors
    proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
  '';
  services.nginx.virtualHosts."nixos.sh" = {
    #listen = [
    #  {
    #    #addr = "[2a05:2d01:2025:f000:dead:beef:cafe:babe]";
    #    port = 443;
    #    ssl = true;
    #  }
    #];
    addSSL = true;
    enableACME = true;
    root = ./.;
  };
  security.acme = {
    acceptTerms = true;
    defaults.email = "letsencrypt@arianvp.me";
  };
}
