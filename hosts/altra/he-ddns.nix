{ lib, pkgs, ... }:
{
  systemd.services.he-ddns = {
    description = "Update he.net DNS for altra.nixos.sh on IPv6 address change";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "exec";
      ExecStart = "${lib.getExe pkgs.he-ddns} -interface bond0 -hostname altra.nixos.sh";
      LoadCredential = "he-ddns.key";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
