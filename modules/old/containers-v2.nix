{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  system = config.nixpkgs.system;
in
{
  options.services.systemd-nspawn = {
    machines = mkOption {
      description = ''
        The NIXOS machines to run.
        For each machine <x>, a corresponding systemd.nspawn.<x>  nixos config is created.
        Override that config to for example configure networking for the container.
      '';
      default = { };
      type = types.attrsOf (
        types.submodule (
          {
            config,
            options,
            name,
            ...
          }:
          {
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
                type = types.nullOr (
                  lib.mkOptionType {
                    name = "Toplevel NixOS config";
                    merge =
                      loc: defs:
                      (pkgs.nixos {
                        imports = map (x: x.value) defs;
                        boot.isContainer = true; # Why is this even needed? Ugly!
                        networking.hostName = mkDefault name;
                        networking.dhcpcd.enable = false;
                        # Workaround for 19.09
                        # TODO figure why this is needed?????????????????
                        networking.useHostResolvConf = false;
                        systemd.network.enable = true;
                      });
                  }
                );
              };
              path = mkOption {
                type = types.path;
                internal = true;
              };
            };
            config = {
              path = config.config.toplevel;
            };
          }
        )
      );
    };
  };
  config = {

    # Set up specific stuff for this machine
    systemd.services."systemd-nspawn@" = {
      environment.MACHINE = "%i";
      # TODO(arianvp): Systemd should set up these directories on startup no?
      preStart = ''
        mkdir -p -m 0755 "/var/lib/machines/$MACHINE/nix" "/var/lib/machines/$MACHINE/etc" "/var/lib/machines/$MACHINE/var/lib"
        mkdir -p -m 0700 /var/lib/machines/$MACHINE/var/lib/private "/var/lib/machines/$MACHINE/root"
      '';
      # Dont run in user-namespace. doesn't work
      serviceConfig.ExecStart = [
        ""
        "${pkgs.systemd}/bin/systemd-nspawn --quiet --keep-unit --boot --link-journal=try-guest --network-veth --settings=override --machine=%i"
      ];
    };

    # Enable she machine on boot
    systemd.targets."machines".wants = map (name: "systemd-nspawn@${name}.service") (
      attrNames config.services.systemd-nspawn.machines
    );

    # Open up DHCP
    networking.firewall.interfaces."vz-nixos".allowedUDPPorts = [
      68
      67
    ];

    systemd.nspawn = flip mapAttrs config.services.systemd-nspawn.machines (
      name: container: {
        execConfig = {
          # We can't use Boot=true as our init system is at
          # ${container.path}/init and not at /sbin/init or /usr/lib/systemd
          # where systemd-nspawn expects it.
          Boot = false;
          Parameters = "${container.path}/init";
          PrivateUsers = "no";
          # When Boot=true this is the default. This causes systemd-nspawn to
          # send SIGTRMIN+3 when it receives SIGTERM, signalling the
          # encapsulated systemd that it should do a graceful shutdown IF THIS
          # IS NOT SET, systemd-nspawn WILL SEND A SIGKILL INSTEAD. WHICH IS
          # BAD.
          KillSignal = "SIGRTMIN+3";
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
      }
    );
  };
}
