{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib.options) mkOption;
  baseOS = import (pkgs.path + "/nixos/lib/eval-config.nix") {
    inherit lib;
    system = null; # use modularly defined system
    baseModules = (import ../../modules/module-list.nix) ++ [
      {
        key = "nodes";
        _module.args.nodes = config.nodes;
      }
    ];
  };
in
{
  inherit (config.system.build) baseOS;
}
/*
  {
  imports = [ ""]
  options = {
    nodes = mkOption {
      type = lib.types.lazyAttrsOf lib.types.deferredModuleWith {
        staticModules = [ ];
      };
    };
  };
  }
*/
