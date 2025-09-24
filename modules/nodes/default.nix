/**
  * Implements a collection of NixOS configurations, similar to NixOS tests.
*/
{
  lib,
  config,
  ...
}:
let
  baseOS = lib.nixosSystem {
    modules = [
      config.defaults
    ];
  };
in
{
  options = {
    node.pkgs = lib.mkOption {
      type = lib.types.nullOr lib.types.pkgs;
    };
    defaults = lib.mkOption {
      type = lib.types.deferredModule;
    };

    nodes = lib.mkOption {
      # This is just submodule
      type = lib.types.lazyAttrsOf baseOS.type;
      visible = "shallow";
      description = ''
        a collection of NixOS configurations.  Each NixOS configuration
        can access the others through the `nodes` parameter.

        NOTE: I guess this makes circular dependencies impossible? but lets try?
      '';
    };
  };
}
