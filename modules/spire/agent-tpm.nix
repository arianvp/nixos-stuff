{
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [ ./agent.nix ];
  spire.agent = {
    settings.plugins.NodeAttestor.tpm = {
      plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_agent";
      plugin_data = { };
    };
  };
  security.tpm2.enable = true;
  systemd.services.spire-agent.serviceConfig = {
    SupplementaryGroups = [ config.security.tpm2.tssGroup ];
  };
}
