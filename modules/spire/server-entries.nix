{
  lib,
  config,
  pkgs,
  utils,
  ...
}:
let
  entryFormat = pkgs.formats.json { };
  cfg = config.spire.server;

  entrySubmodule =
    { name, ... }:
    {
      options = {
        selectors = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                type = lib.mkOption {
                  type = lib.types.str;
                  description = "Selector type (e.g., 'unix:uid', 'k8s:sa', etc.)";
                };
                value = lib.mkOption {
                  type = lib.types.str;
                  description = "Selector value";
                };
              };
            }
          );
          default = [ ];
          description = "A list of selectors that identify the workload";
        };

        parent_id = lib.mkOption {
          type = lib.types.oneOf [
            lib.types.str
            (lib.types.enum "spiffe://${cfg.trustDomain}/spire/server")
          ];
          description = "The SPIFFE ID of an entity that is authorized to attest the validity of a selector";
        };

        spiffe_id = lib.mkOption {
          type = lib.types.str;
          description = "The SPIFFE ID for this registration entry";
        };

        x509_svid_ttl = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Time to live for X509-SVIDs generated from this entry (in seconds)";
        };

        federates_with = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "A list of federated trust domain SPIFFE IDs";
        };

        entry_id = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = name;
          description = "Entry ID";
        };

        admin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether the workload is an admin workload";
        };

        downstream = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "To enable signing CA CSR in upstream spire server";
        };

        entryExpiry = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Expiration of this entry, in seconds from epoch";
        };

        dns_names = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "DNS entries";
        };

        store_svid = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Determines if the issued SVID must be stored through an SVIDStore plugin";
        };

        jwt_svid_ttl = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          description = "Time to live for JWT-SVIDs generated from this entry (in seconds)";
        };

        hint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "An operator-specified string used to provide guidance on how this identity should be used";
        };
      };
    };

  makeEntry =
    entryID: entry:
    lib.nameValuePair "spire-server-create-entry-${entryID}" {
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "spire-server-create-entry-${entryID}";
          runtimeInputs = [ pkgs.spire ];
          text = ''
            spire-server entry show -socketPath /run/spire-server/private/api.sock -entryID "${entryID}"|| spire-server entry create -socketPath /run/spire-server/private/api.sock -data "${
              entryFormat.generate "entries.json" {
                entries = [ entry ];
              }
            }"
          '';
        }
      );
    };
in
{
  options.spire.server.entries = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule entrySubmodule);
    default = { };
    description = "SPIRE server entries. Currently can only create entries. updating and deleting is not supported.";
  };

  config.systemd.services = lib.mapAttrs' makeEntry cfg.entries;

  /*
    lib.mkIf (cfg.entries != [ ]) {
      systemd.services.spire-server-create-entries = {
        description = "SPIRE server entry creation service";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellApplication {
            name = "spire-server-create-entries";
            args = [ ];
            shell = pkgs.bashInteractive;
            code = ''
              ${pkgs.spire}/bin/spire-server entry create -data ${
                entryFormat.generate "entries.json" { entries = cfg.entries; }
            '';
          };
        };
      };
    };
  */
}
