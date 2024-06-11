{ pkgs, lib, config, ... }:
{
  system.activationScripts.diff = {
    supportsDryActivation = true;
    text = ''
      if [ -e /run/current-system ]; then
        ${lib.getExe config.nix.package} store diff-closures /run/current-system "$systemConfig"
      fi
    '';
  };
}
