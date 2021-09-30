{ lib, pkgs, config, modulesPath, ...}:
{
  imports = [
     (modulesPath + "/virtualisation/digital-ocean-image.nix")
    ../../modules/containers-v2.nix
    ./network.nix
  ];

  system.stateVersion = "19.03";

  # needed for networkd to function. obscure
  time.timeZone = "Europe/Amsterdam";

  # Weechat
  services.weechat.enable = true;
  networking.firewall.allowedTCPPorts = [
    80   # http
    443  # https
    4443 # weechat relay
  ];


  programs.screen.screenrc = ''
    multiuser on
    acladd normal_user
  '';

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

      # This might create errors
      proxy_cookie_path / "/; secure; HttpOnly; SameSite=strict";
    '';
    virtualHosts = {
      "arianvp.me" = {
        forceSSL = true;
        enableACME = true;
        locations."/".root = ../../website;
        # locations."/chrome-reproducer".index = "${../../chrome-reproducer.html}";
      };
      /*"techstock.photos" = {
        forceSSL = true;
        enableACME = true;
        locations."/reproducer".root = pkgs.writeTextDir "index.html"
        ''
          ${../../chrome-reproducer.html}
          '';
      };*/
    };
  };

  # Needed to accept terms
  security.acme.email = "arian.vanputten@gmail.com";
  security.acme.acceptTerms = true;


  users.users.root.openssh.authorizedKeys.keyFiles = [
    (pkgs.fetchurl {
      url = "https://github.com/arianvp.keys";
      sha256 = "1q63gl8f0384w00dvqsb5kv4hjp71gwsfm4dr41r0y39mc4ca7f4";
    })
  ];

}
