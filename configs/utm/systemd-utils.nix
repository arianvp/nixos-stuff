{ utils, config, lib, ... }:
let inherit (lib) types mkOption;

  socketShorthand = {
    options.systemd.services = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          listenStream = mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      });
    };
    config.systemd.sockets =
      let servicesToActivate = lib.filterAttrs (_: value: value.listenStream != [ ]) config.systemd.services;
      in lib.mapAttrs
        (name: value: {
          wantedBy = [ "sockets.target" ];
          socketConfig = { ListenStream = value.listenStream; };
        })
        servicesToActivate;
  };
  socketProxy = {
    options.systemd.socketProxies = mkOption {
      description = ''
      Allows you to set up socket activation for services that do not natively support it.

      Note that for this to work the service in question needs to either have Type=notify
      or have a health check defined in ExecStartPost that will only return after the
      service is up.
      '';
      type = types.attrsOf (types.submodule ({ name, ... }: {
        options = {
          listenStream = mkOption {
            type = lib.types.listOf lib.types.str;
            description = "The address the socket unit will listen on";
            default = [ ];
          };
          service = mkOption {
            type = lib.types.str;
            default = name;
            defaultText = "name";
            description = "The name of the service without socket activation to proxy to";
          };
          address = mkOption {
            type = lib.types.str;
            description = "The address the service without socket activation is listening on";
          };
        };
      }));
    };
    config.systemd.services = lib.mapAttrs'
      (name: value: lib.nameValuePair "systemd-socket-proxy@${utils.escapeSystemdPath name}" {
        requires = [ "${value.service}.service" ];
        after = [ "${value.service}.service" ];
        listenStream = value.listenStream;
        serviceConfig = {
          Type = "notify";
          ExecStart = "${config.systemd.package}/lib/systemd/systemd-socket-proxyd ${value.address}";
        };
      })
      config.systemd.socketProxies;
  };

in
{
  imports = [
    socketShorthand
    socketProxy
  ];
}

