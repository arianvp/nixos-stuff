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

  # TODO: upstream
  systemd.tmpfiles.rules = [
   "z-	/sys/kernel/security/tpm[0-9]/binary_bios_measurements	0440  root tss	-	    -"
  ];
  systemd.services.spire-agent.serviceConfig = {
    SupplementaryGroups = [ config.security.tpm2.tssGroup ];
  };
}
