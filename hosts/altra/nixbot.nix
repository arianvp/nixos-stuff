nixbot:
{ config, options, ... }:
let
  # `cloudflared tunnel create nixbot` prints this and names its credentials file after it.
  tunnelId = "5d074d69-3044-4137-a9cd-bbf74a454d6b";
in
{
  imports = [
    nixbot.nixosModules.nixbot
  ];

  services.nixbot = {
    enable = true;
    # This line has no inbound IPv4, so everything goes through the Cloudflare
    # tunnel, which terminates TLS and makes nixbot reachable over IPv4.
    domain = "nixbot.passkey.exchange";
    useHTTPS = true;
    nginx.enable = false;
    admins = [ "github:arianvp" ];
    # Lets opkssh bind ID tokens to its SSH key, see ./patches/nixbot-id-token-nonce.patch.
    packages.nixbot = options.services.nixbot.packages.nixbot.default.overridePythonAttrs (old: {
      patches = old.patches or [ ] ++ [ ./patches/nixbot-id-token-nonce.patch ];
    });
    buildSystems = [ "aarch64-linux" ];

    github = {
      enable = true;
      appId = 4760601;
      appSecretKeyFile = "/etc/credstore/nixbot-github-app.pem";
      webhookSecretFile = "/etc/credstore/nixbot-github-webhook";
      oauthId = "Iv23li8ZTMYXcUgzcvqD";
      oauthSecretFile = "/etc/credstore/nixbot-github-oauth";
      topic = "nixbot-altra";
    };

    # PRs build on this machine, so outsiders' PRs wait for a maintainer to approve them.
    # CONTRIBUTOR is dropped: a single merged commit shouldn't grant free rein.
    prApproval = {
      enable = true;
      trustedAssociations = [
        "OWNER"
        "MEMBER"
        "COLLABORATOR"
      ];
    };
  };

  services.cloudflared = {
    enable = true;
    tunnels.${tunnelId} = {
      credentialsFile = "/etc/credstore/cloudflared-nixbot.json";
      ingress."nixbot.passkey.exchange" = "http://localhost:${toString config.services.nixbot.port}";
      default = "http_status:404";
    };
  };
}
