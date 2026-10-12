nixbot:
{ ... }:
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
    domain = "nixbot.nixos.sh";
    admins = [ "github:arianvp" ];
    buildSystems = [ "aarch64-linux" ];

    # GitHub cannot yet deliver webhooks over IPv6 and this line has no inbound
    # IPv4, so deliveries come in over the tunnel while the UI stays on `domain`.
    webhookBaseUrl = "https://nixbot.passkey.exchange";

    github = {
      enable = true;
      appId = 4760601;
      appSecretKeyFile = "/etc/credstore/nixbot-github-app.pem";
      webhookSecretFile = "/etc/credstore/nixbot-github-webhook";
      oauthId = "Iv23li8ZTMYXcUgzcvqD";
      oauthSecretFile = "/etc/credstore/nixbot-github-oauth";
      topic = "nixbot-altra";
    };
    nginx.enableACME = true;

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
      ingress."nixbot.passkey.exchange" = {
        path = "^/webhooks/";
        service = "unix:/run/nixbot/web.sock";
      };
      default = "http_status:404";
    };
  };

  # cloudflared runs as a DynamicUser; the nixbot socket is 0660 nixbot:nixbot.
  systemd.services."cloudflared-tunnel-${tunnelId}".serviceConfig.SupplementaryGroups = [
    "nixbot"
  ];
}
