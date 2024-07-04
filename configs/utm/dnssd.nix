{ config, pkgs, lib, ... }:
let
  cfg = config.systemd.dnssd;
  fmt = pkgs.formats.ini { };
  serviceModule = { name, options, config, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
      };
      type = lib.mkOption {
        type = lib.types.str;
      };
      port = lib.mkOption {
        type = lib.types.int;
      };
      text = lib.mkOption {
        type = lib.types.str;
        internal = true;
        readOnly = true;
      };
      path = lib.mkOption {
        type = lib.types.str;
        internal = true;
        readOnly = true;
      };
    };
    config = {
      path = "systemd/dnssd/${name}.dnssd";
      text = ''
        [Service]
        Name=${name}
        Type=${config.type}
        Port=${toString config.port}
      '';
    };
  };
in
{
  options.systemd.dnssd = {
    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule serviceModule);
    };
  };

  config.environment.etc = lib.mapAttrs' (_: v: lib.nameValuePair v.path { inherit (v) text; }) cfg.services;
  config.systemd.services.systemd-resolved = {
    stopIfChanged = false;
    reloadTriggers = lib.mapAttrsToList (_: v: config.environment.etc.${v.path}.source) cfg.services;
  };
}
