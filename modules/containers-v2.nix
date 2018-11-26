{ config, lib, pkgs, ... }:
with lib;
let
  system = config.nixpkgs.system;
in
{
  options.containers-v2 = mkOption {
    type = types.attrsOf (types.submodule (
      { config, options, name, ... }: {
        options = {
          config = mkOption {
            description = ''
              A specification of the desired configuration of this
              container, as a NixOS module.
            '';
            type = lib.mkOptionType {
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
            };
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
  config = {
    systemd.services."systemd-nspawn@".serviceConfig = {
      # TODO make this better
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
      map (name:  "systemd-nspawn@${name}.service") (attrNames config.containers-v2);

    systemd.nspawn =
      flip mapAttrs config.containers-v2 (name: container: {
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

