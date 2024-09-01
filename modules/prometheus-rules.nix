{ pkgs, lib, config, ... }:
let
  fmt = pkgs.formats.yaml { };
in
{
  options.services.prometheus.structuredRules = lib.mkOption {
    type = lib.types.submodule {
      freeformType = fmt.type;
    };
    default = { };
  };

  config.services.prometheus.ruleFiles = [ (fmt.generate "rules.yml" config.services.prometheus.structuredRules) ];
}
