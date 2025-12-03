{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.systemd.dnssd;
  fmt = pkgs.formats.ini { };
  serviceModule =
    {
      name,
      options,
      config,
      ...
    }:
    {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          default = name;
        };
        type = lib.mkOption {
          type = lib.types.str;
        };
        subType = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
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
          Name=${config.name}
          Type=${config.type}
          ${lib.optionalString (config.subType != null) "SubType=${config.subType}"}
          Port=${toString config.port}
        '';
      };
    };
in
{
  options.systemd.dnssd = {
    services = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule serviceModule);
      default = { };
    };
  };

  config.environment.etc = lib.mapAttrs' (
    _: v: lib.nameValuePair v.path { inherit (v) text; }
  ) cfg.services;
  config.services.resolved.enable = lib.mkDefault true;
  config.systemd.services.systemd-resolved = {
    stopIfChanged = false;
    reloadTriggers = lib.mapAttrsToList (_: v: config.environment.etc.${v.path}.source) cfg.services;
  };
  config.networking.firewall.allowedUDPPorts = [ 5353 ]; # mDNS
}
