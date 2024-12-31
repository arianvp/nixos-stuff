{
  lib,
  config,
  pkgs,
  ...
}:
{
  boot.kernelParams = [ "audit=1" ];
  security.audit.enable = true;

  # audit usage of any  suid/guid binaries.
  # On NixOS it is guaranteed that no suid binaries are present out side of /run/wrappers
  security.audit.rules = (
    lib.mapAttrsToList (
      wrapName: wrap:
      "-a always,exit -F path=${wrap.source} -F perm=x -F auid>=1000 -F auid!=unset -k security.wrappers.${wrapName}"
    ) config.security.wrappers
  );

  systemd.sockets."systemd-journald-audit".wantedBy = [ "sockets.target" ];

  security.auditd.enable = true;
}
