{ config, pkgs, lib, ...}:
with lib;
let
  cfg = config.services.gitlab-runner2;
  profile = pkgs.buildEnv { paths = [ pkgs.nix ]; };
in
  {
    options.services.gitlab-runner2 = {
      enable = lib.mkEnableOption "Gitlab Runner";
      registrationConfigFile = lib.mkOption {
        description = ''
          Configuration file used got gitlab-runner registration.
          It is a list of environment variables. 
          A list of all supported environment variables can be found
          in
             gitlab-runner register --help

          One that you probably want to set is
          CI_SERVER_URL=<CI server URL>
          CI_SERVER_TOKEN=<registration secret>

        '';
        type = lib.types.path;
      };

      gracefulTermination = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Finish all remaining jobs before stopping, restarting or reconfiguring.
          If not set gitlab-runner will stop immediatly without waiting for jobs to finish,
          which will lead to failed builds.
        '';
      };

      gracefulTimeout = mkOption {
        default = "infinity";
        type = types.str;
        example = "5min 20s";
        description = ''Time to wait until a graceful shutdown is turned into a forceful one.'';
      };

      workDir = mkOption {
        default = "/var/lib/gitlab-runner";
        type = types.path;
        description = "The working directory used";
      };

      package = mkOption {
        description = "Gitlab Runner package to use";
        default = pkgs.gitlab-runner;
        defaultText = "pkgs.gitlab-runner";
        type = types.package;
        example = literalExample "pkgs.gitlab-runner_1_11";
      };

      packages = mkOption {
        default = [ pkgs.bash pkgs.docker-machine ];
        defaultText = "[ pkgs.bash pkgs.docker-machine ]";
        type = types.listOf types.package;
        description = ''
          Packages to add to PATH for the gitlab-runner process.
        '';
      };
    };
    config = mkIf cfg.enable {
      systemd.services.gitlab-runner2 = {
        path = cfg.packages;
        environment = config.networking.proxy.envVars;
        description = "Gitlab Runner";
        after = [ "network.target" "docker.service"];
        requires = ["docker.service"];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          EnvironmentFile = "${cfg.registrationConfigFile}";
          ExecStartPre = ''${cfg.package.bin}/bin/gitlab-runner register \
            --non-interactive=true \
            --name gitlab-runner \
            --executor "docker" \
            --docker-image "nixos/nix" \
            --docker-volumes /nix/store:/nix/store:ro \
            --docker-volumes /nix/var/nix/db:/nix/var/nix/db:ro \
            --docker-volumes /nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro \
            --docker-disable-cache=true \
            --env "NIX_REMOTE=daemon" \
            --pre-build-script "export PATH=${pkgs.nix}/bin:$PATH\n apk add ca-certificates" \
          ''; 
          ExecStart = ''${cfg.package.bin}/bin/gitlab-runner run \
            --working-directory ${cfg.workDir} \
            --user gitlab-runner \
            --service gitlab-runner \
          '';
          ExecStopPost = ''${cfg.package.bin}/bin/gitlab-runner unregister \
            --name gitlab-runner
          '';

        } //  optionalAttrs (cfg.gracefulTermination) {
          TimeoutStopSec = "${cfg.gracefulTimeout}";
          KillSignal = "SIGQUIT";
          KillMode = "process";
        };
      };

      virtualisation.docker.enable = true;

      # Make the gitlab-runner command availabe so users can query the runner
      environment.systemPackages = [ cfg.package ];

      users.users.gitlab-runner = {
        group = "gitlab-runner";
        extraGroups = ["docker"];
        uid = config.ids.uids.gitlab-runner;
        home = cfg.workDir;
        createHome = true;
      };

      users.groups.gitlab-runner.gid = config.ids.gids.gitlab-runner;
    };
  }
