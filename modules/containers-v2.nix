{ config, lib, pkgs, ... }:
with lib;
let
  system = config.nixpkgs.system;
in
{
  options.services.systemd-nspawn =  {
    machines =  mkOption {
      description = ''
        The NIXOS machines to run.
        For each machine <x>, a corresponding systemd.nspawn.<x>  nixos config is created.
        Override that config to for example configure networking for the container.
      '';
      default = {};
      type = types.attrsOf (types.submodule (
        { config, options, name, ... }: {
          options = {
            config = mkOption {
              description = ''
                if null, then it is assumed that /var/lib/machines/<name> exists, and is a full machine image.
                Systemd-nspawn will then start up this image as it would normally do.

                Otherwise, provide a NixOS configuration. It will then, similarily to nixos-container,
                create a machine directory on demand, and bind-mount the closure of the NixOS derivation
                inside the container.
              '';
              default = null;
              type = types.nullOr (lib.mkOptionType {
                name = "Toplevel NixOS config";
                # TODO remove absolute path
                merge = loc: defs: (import ../../nixpkgs/nixos/lib/eval-config.nix {
                  inherit system;
                  modules =
                    let extraConfig =
                      { boot.isContainer = true;
                        networking.hostName = mkDefault name;
                        networking.useDHCP = false;
                      };
                    in [ extraConfig ] ++ (map (x: x.value) defs);
                  prefix = [ "containers" name ];
                }).config;
              });
            };
            path = mkOption {
              type = types.path;
              internal = true;
            };
          };
          config = {
            path = config.config.system.build.toplevel;
          };
        }
      ));
    };
  };
  config = {

    # Set up specific stuff for this machine
    systemd.services."systemd-nspawn@" = {
      environment.MACHINE = "%i";
      preStart = ''
        mkdir -p -m 0755 "/var/lib/machines/$MACHINE/nix" "/var/lib/machines/$MACHINE/etc" "/var/lib/machines/$MACHINE/var/lib"
        mkdir -p -m 0700 /var/lib/machines/$MACHINE/var/lib/private "/var/lib/machines/$MACHINE/root"
      '';
    };

    # Enable she machine on boot
    systemd.targets."machines".wants = 
      map (name:  "systemd-nspawn@${name}.service") (attrNames config.services.systemd-nspawn.machines);

    systemd.nspawn =
      flip mapAttrs config.services.systemd-nspawn.machines (name: container: {
        execConfig = {
          Boot = false;
          Parameters = "${container.path}/init";
          PrivateUsers = "yes";
        };
        networkConfig = {
          Zone = "nixos";
        };
        filesConfig = {
          BindReadOnly = [ 
            "/nix/store"
            "/nix/var/nix/db"
            "/nix/var/nix/daemon-socket"
          ];
        };
      });
  };
}
