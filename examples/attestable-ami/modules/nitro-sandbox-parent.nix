# Launches a Nitro Sandbox at boot with Firecracker, and prints what it sends
# over vsock to the console.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.nitro-sandbox;
  inherit (cfg) guest;
  socket = "/run/nitro-sandbox/v.sock";

  firecrackerConfig =
    pkgs.runCommand "nitro-sandbox.json"
      {
        nativeBuildInputs = [ pkgs.buildPackages.jq ];
        config = builtins.toJSON {
          boot-source = {
            kernel_image_path = guest.kernel;
            initrd_path = guest.initrd;
          };
          machine-config = {
            vcpu_count = 1;
            mem_size_mib = 512;
          };
          drives = [
            {
              drive_id = "system";
              path_on_host = guest.drive;
              is_root_device = false;
              is_read_only = true;
            }
          ];
          vsock = {
            guest_cid = 3;
            uds_path = socket;
          };
          # Makes it a sandbox rather than a KVM microVM. Confidential mode,
          # the default, keeps the sandbox's memory out of the parent's reach.
          enclave.cpu_overcommit = true;
        };
        passAsFile = [ "config" ];
      }
      ''
        jq --rawfile cmdline ${guest.cmdline} '."boot-source".boot_args = $cmdline' \
          $configPath > $out
      '';
in
{
  imports = [ ./nitro-sandbox-kernel.nix ];

  options.services.nitro-sandbox.guest = lib.mkOption {
    type = lib.types.attrs;
    description = "The sandbox to launch: a guest system's `system.build.nitro-sandbox`.";
  };

  config = {
    # Sandboxes get their memory from a pool the parent reserves at boot.
    boot.kernelParams = [ "nitro_enclaves.mempool=2G@0" ];

    # Connections from the sandbox to the parent's port N arrive at
    # `${socket}_N`.
    systemd.sockets.nitro-sandbox-listener = {
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "${socket}_${toString guest.port}";
        Accept = true;
      };
    };
    systemd.services."nitro-sandbox-listener@" = {
      description = "Print what the Nitro Sandbox sends";
      serviceConfig = {
        ExecStart = "${pkgs.coreutils}/bin/cat";
        StandardInput = "socket";
        StandardOutput = "journal+console";
      };
    };

    systemd.services.nitro-sandbox = {
      description = "Nitro Sandbox";
      wantedBy = [ "multi-user.target" ];
      after = [ "sockets.target" ];
      # Only on instances launched with enclaves enabled.
      unitConfig.ConditionPathExists = "/dev/nitro_enclaves";
      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe pkgs.firecracker} --no-api --config-file ${firecrackerConfig}";
        # Why the sandbox didn't start, on the console of an instance nobody
        # can log in to.
        StandardOutput = "journal+console";
        StandardError = "journal+console";
      };
    };
  };
}
