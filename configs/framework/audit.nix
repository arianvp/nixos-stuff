{
  lib,
  config,
  pkgs,
  ...
}:
# audit any execution of nix store paths that are outside of /ru/current-system's closure

let
  inherit (config.nixpkgs.hostPlatform) linuxArch;
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

  # Don't allow any  binaries outside of nix store
  # fileSystems."/".options = [ "nosuid" "nodev" "noexec" ];

  system.build.rules = rules;

  # nix store can have executables
  # fileSystems."/nix/store" = { device = "none"; options = [ "bind" "nosuid" "nodev" ]; };

  # audit usage of any  suid/guid binaries.
  # On NixOS it is guaranteed that no suid binaries are present out side of /run/wrappers
  security.audit.rules =
    [
      # ANIX-00-000210
      # NixOS must generate audit records for all usage of privileged commands.
      "-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k execpriv"
      "-a always,exit -F arch=b32 -S execve -C gid!=egid -F egid=0 -k execpriv"
      "-a always,exit -F arch=b64 -S execve -C gid!=egid -F egid=0 -k execpriv"

      # ANIX-00-000270
      # Successful/unsuccessful uses of the mount syscall in NixOS must generate an
      # audit record.
      "-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"
      "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -k privileged-mount"

      # ANIX-00-000280
      # Successful/unsuccessful uses of the rename, unlink, rmdir, renameat, and unlinkat system calls in NixOS must generate an audit record.
      # NOTE: this is extremely noisy
      # "-a always,exit -F arch=b32 -S rename,unlink,rmdir,renameat,unlinkat -F auid>=1000 -F auid!=unset -k delete"
      # "-a always,exit -F arch=b64 -S rename,unlink,rmdir,renameat,unlinkat -F auid>=1000 -F auid!=unset -k delete"

      # ANIX-00-000290
      # Successful/unsuccessful uses of the init_module, finit_module, and delete_module system calls in NixOS must generate an audit record.
      "-a always,exit -F arch=b32 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
      "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -F auid>=1000 -F auid!=unset -k module_chng"
    ]
    ++

      (lib.mapAttrsToList (
        _: wrap:
        "-a always,exit -F arch=${linuxArch} -F path=${config.security.wrapperDir}/${wrap.program} -F perm=x -F auid>=1000 -F auid!=unset -k security.wrappers.${wrap.program}"
      ) config.security.wrappers)
    ++ [
    ];

  systemd.sockets."systemd-journald-audit".wantedBy = [ "sockets.target" ];

  security.auditd.enable = true;
}
