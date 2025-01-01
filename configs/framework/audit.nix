{
  lib,
  config,
  pkgs,
  ...
}:
# audit any execution of nix store paths that are outside of /ru/current-system's closure

let
  inherit  (config.nixpkgs.hostPlatform) linuxArch;
  rules =
    pkgs.runCommand "closure.rules"
      {
        closure = pkgs.closureInfo {
          rootPaths = [ config.system.build.toplevel ];
        };
      }
      ''
        while read path; do
          echo "-a always,exit -F arch=${config.nixpkgs.hostPlatform.linuxArch} -F dir=$path -F perm=x -F auid>=1000 -F auid!=unset -k current-system"
        done < "$closure/store-paths" >> $out

        # complain about executions that are not in the current system.
        # this means someone got some executable on the machine that we didn't ship.
        # this is most likely malicious

      '';
in

{
  boot.kernelParams = [ "audit=1" ];
  security.audit.enable = true;

  # Don't allow any  binaries outside of nix store
  # fileSystems."/".options = [ "nosuid" "nodev" "noexec" ];

  system.build.rules = rules;

  # nix store can have executables
  # fileSystems."/nix/store" = { device = "none"; options = [ "bind" "nosuid" "nodev" ]; };

  # audit usage of any  suid/guid binaries.
  # On NixOS it is guaranteed that no suid binaries are present out side of /run/wrappers
  security.audit.rules = (
    lib.mapAttrsToList (_: wrap:
      "-a always,exit -F arch=${linuxArch} -F path=${config.security.wrapperDir}/${wrap.program} -F perm=x -F auid>=1000 -F auid!=unset -k security.wrappers.${wrap.program}"
    ) config.security.wrappers
  ) ++ [
    # Audit usage of nix
    "-a always,exit -F arch=${linuxArch} -F perm=x -F dir=${config.nix.package} -F auid>=1000 -F auid!=unset -key nix"
    "-a always,exit -F arch=${linuxArch} -S connect -F name=/nix/var/nix/daemon-socket/socket -F auid>=1000 -F auid!=unset -k nix"
  ];

  systemd.sockets."systemd-journald-audit".wantedBy = [ "sockets.target" ];

  security.auditd.enable = true;
}
