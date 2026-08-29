nixbot:
{ ... }:
{
  imports = [
    nixbot.nixosModules.nixbot
  ];

  services.nixbot = {
    enable = true;
    domain = "nixbot.nixos.sh";
    admins = [ "github:arianvp" ];
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
    nginx.enableACME = true;
  };
}
