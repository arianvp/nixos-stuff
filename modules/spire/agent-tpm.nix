{ lib, pkgs, ... }:
{
  imports = [ ./agent.nix ];
  spire.agent = {
    settings.plugins.NodeAttestor.tpm = {
      plugin_cmd = lib.getExe' pkgs.spire-tpm-plugin  "tpm_attestor_agent";
      plugin_data = {};
    };
  };
}
