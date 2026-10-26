{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.spire.svids;
  agentSocket = config.services.spire.agent.settings.agent.socket_path;
  format = pkgs.formats.hcl1 { };

  svidModule =
    { name, config, ... }:
    {
      options = {
        socketPath = lib.mkOption {
          type = lib.types.str;
          default = agentSocket;
          defaultText = lib.literalExpression "config.services.spire.agent.settings.agent.socket_path";
          description = "Path to the SPIFFE Workload API socket.";
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "root";
          description = "Group that may read the private key.";
        };

        directoryMode = lib.mkOption {
          type = lib.types.str;
          default = "0750";
          description = ''
            Mode of {option}`directory`. The certificate and bundle are world
            readable inside it; the key only by {option}`group`.
          '';
        };

        restartOnBundleChange = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "etcd.service" ];
          description = ''
            Units to restart when a CA is added to the trust bundle, for
            software that reads its CA certificates only on startup. SPIRE adds
            the next CA well before it signs with it.
          '';
        };

        restartMaxDelaySec = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 0;
          description = ''
            Upper bound of a random delay before restarting
            {option}`restartOnBundleChange`, so that a fleet does not restart at
            once. It must be shorter than the time between SPIRE preparing a CA
            and activating it.
          '';
        };

        unit = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "${name}-svid.service";
          description = ''
            The unit that fetches and rotates the SVID. The unit is active once
            all files exist. Registration entries for this SVID select
            `systemd:id:''${unit}`.
          '';
        };

        directory = lib.mkOption {
          type = lib.types.str;
          readOnly = true;
          default = "/run/${name}-svid";
          description = "Directory that holds the SVID files.";
        };

        paths = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          readOnly = true;
          default = {
            cert = "${config.directory}/svid.pem";
            key = "${config.directory}/svid.key";
            bundle = "${config.directory}/bundle.pem";
          };
          description = ''
            Paths of the files: `cert` (the X509-SVID followed by its
            intermediates), `key` and `bundle` (the X.509 trust bundle).
          '';
        };
      };
    };

  helperConfig =
    svid:
    format.generate "spiffe-helper.conf" {
      agent_address = svid.socketPath;
      cert_dir = svid.directory;
      daemon_mode = true;
      svid_file_name = baseNameOf svid.paths.cert;
      svid_key_file_name = baseNameOf svid.paths.key;
      svid_bundle_file_name = baseNameOf svid.paths.bundle;
      cert_file_mode = 420; # 0644
      key_file_mode = 416; # 0640
    };
in
{
  options.spire.svids = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule svidModule);
    default = { };
    description = ''
      X509-SVIDs that spiffe-helper keeps on disk and rotates before they expire,
      for software that reads its certificates from files.
    '';
  };

  config = lib.mkIf (cfg != { }) {
    systemd.services = lib.mkMerge (
      lib.mapAttrsToList (
        name: svid:
        let
          unitName = lib.removeSuffix ".service" svid.unit;
          # The bundle the consumers started with
          knownBundle = "${svid.directory}/.bundle.known";
        in
        {
          ${unitName} = {
            description = "SVIDs for ${name}";
            wantedBy = [ "multi-user.target" ];
            after = [ "spire-agent.service" ];
            wants = [ "spire-agent.service" ];
            # Retry until the agent has attested and received the entry
            startLimitIntervalSec = 0;
            serviceConfig = {
              ExecStart = "${lib.getExe' pkgs.spiffe-helper "spiffe-helper"} -config ${helperConfig svid}";
              ExecStartPost = pkgs.writeShellScript "wait-for-svid" ''
                until ${lib.concatMapStringsSep " && " (p: "[ -s ${p} ]") (lib.attrValues svid.paths)}; do
                  sleep 0.2
                done
                [ -e ${knownBundle} ] || cp ${svid.paths.bundle} ${knownBundle}
              '';
              TimeoutStartSec = "2min";
              Restart = "always";
              RestartSec = "5s";
              Group = svid.group;
              UMask = "0022";
              RuntimeDirectory = baseNameOf svid.directory;
              RuntimeDirectoryMode = svid.directoryMode;
              # Consumers keep using the old files while the helper restarts
              RuntimeDirectoryPreserve = true;
            };
          };
        }
        // lib.optionalAttrs (svid.restartOnBundleChange != [ ]) {
          # spiffe-helper rewrites the bundle whenever it renews the SVID, and
          # removing an expired CA needs no restart, so look for new CAs
          "${unitName}-bundle" = {
            description = "Restart consumers of the trust bundle of ${name}";
            path = [ pkgs.gawk ];
            environment.LC_ALL = "C";
            serviceConfig = {
              Type = "oneshot";
              TimeoutStartSec = "infinity";
            };
            script = ''
              # Consumers start once the first bundle is known
              if [ ! -e ${knownBundle} ]; then
                cp ${svid.paths.bundle} ${knownBundle}
                exit 0
              fi
              certs() { awk '/BEGIN CERT/ { c = "" } { c = c $0 } /END CERT/ { print c }' "$1" | sort; }
              cp ${svid.paths.bundle} ${knownBundle}.new
              added=$(comm -13 <(certs ${knownBundle}) <(certs ${knownBundle}.new))
              mv ${knownBundle}.new ${knownBundle}
              if [ -n "$added" ]; then
                sleep $((RANDOM % ${toString (svid.restartMaxDelaySec + 1)}))
                systemctl try-restart ${lib.escapeShellArgs svid.restartOnBundleChange}
              fi
            '';
          };
        }
      ) cfg
    );

    systemd.paths = lib.mapAttrs' (
      name: svid:
      lib.nameValuePair "${lib.removeSuffix ".service" svid.unit}-bundle" {
        wantedBy = [ "multi-user.target" ];
        pathConfig.PathChanged = svid.paths.bundle;
      }
    ) (lib.filterAttrs (_: svid: svid.restartOnBundleChange != [ ]) cfg);
  };
}
