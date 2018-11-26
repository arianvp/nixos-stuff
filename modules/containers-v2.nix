{ config, lib, pkgs, ... }:
with lib;
let
  system = config.nixpkgs.system;
in
{
  options.services.systemd-nspawn =  {
    machines =  mkOption {
      description = ''
        The machines to run
      '';
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
                merge = loc: defs: (import <nixpkgs/nixos/lib/eval-config.nix> {
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
    systemd.services."systemd-nspawn@".serviceConfig = {
      # TODO make this better
      # TODO Add conditionals to only do this if the directories don't exist yet
      # TODO don't add the gcroot stuff is the container wasn't a NixOS container

      ExecStartPre =  [
        # Create a gcroot and a profile for the container, such that it doesn't get garbage-collected
        "${pkgs.coreutils}/bin/mkdir -p -m 0755 /nix/var/nix/profiles/per-machine/%i /nix/var/nix/gcroots/per-machine/%i"

        # Create a directory for the container state to live in.  And pre-populate it with some stuff, such
        # that systemd doesn't get mad
        "${pkgs.coreutils}/bin/mkdir -p -m 0755 /var/lib/machines/%i/etc /var/lib/machines/%i/var/lib"
        "${pkgs.coreutils}/bin/mkdir -p -m 0700 /var/lib/machines/%i/var/lib/private /var/lib/machines/%i/root"
      ];
    };
    systemd.targets."machines".wants = 
      map (name:  "systemd-nspawn@${name}.service") (attrNames config.services.systemd-nspawn.machines);

    systemd.nspawn =
      flip mapAttrs config.services.systemd-nspawn.machines (name: container: {
        execConfig = {
          Boot = false;
          Parameters = "${container.path}/init";
          # LinkJournal = "try-guest"; we should fix upstream for this
        };
        filesConfig = {
          BindReadOnly = [ 
            "/nix/store"
            "/nix/var/nix/db"
            "/nix/var/nix/daemon-socket"
          ];
          Bind = [ 
            "/nix/var/nix/profiles/per-machine/${name}:/nix/var/nix/profiles" 
            "/nix/var/nix/gcroots/per-machine/${name}:/nix/var/nix/gcroots"
          ];
        };
      });
  };
}

