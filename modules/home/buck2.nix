{
  config,
  lib,
  pkgs,
  ...
}:
let
  ini = pkgs.formats.ini { listToValue = lib.concatStringsSep ","; };
in
{
  options.programs.buck2.buckconfigs = lib.mkOption {
    type = lib.types.attrsOf ini.type;
    default = { };
    description = ''
      Files in ~/.buckconfig.d, keyed by file name. Lists are joined with ","
      so that modules can each contribute entries to keys like project.ignore.
    '';
  };

  config.home.file = lib.mapAttrs' (
    name: settings: lib.nameValuePair ".buckconfig.d/${name}" { source = ini.generate name settings; }
  ) config.programs.buck2.buckconfigs;
}
