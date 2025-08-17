{
  lib,
  config,
  modulesPath,
  ...
}:
let
  baseOS = lib.evalModules {
    modules = [
      {
        _module.args = {
          inherit (config) nodes;
        };
      }
      config.defaults
    ]
    ++ (import "${modulesPath}/module-list.nix");
  };
in
{
  options.defaults = lib.mkOption {
    type = lib.types.deferredModule;
  };

  options.nodes = lib.mkOption {
    # This is just submodule
    type = lib.types.lazyAttrsOf baseOS.type;
  };
}
