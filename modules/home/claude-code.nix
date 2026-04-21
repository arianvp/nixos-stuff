{ pkgs, lib, ... }:
{
  programs.claude-code = {
    enable = true;
    settings = {
      sandbox = {
        enabled = true;
        failIfUnavailable = true;
        filesystem = {
          denyWrite = [ "/" ];
          denyRead = [ "/" ];
          allowRead = [
            "."
            "/nix/store"
            "/nix/var/nix/daemon-socket/socket"
          ];
          allowWrite = [
            "."
            "/nix/var/nix/daemon-socket/socket"
          ];
        };
        network = {
          allowUnixSockets = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [ "/nix/var/nix/daemon-socket/socket" ];
          allowAllUnixSockets = pkgs.stdenv.hostPlatform.isLinux;
          allowedDomains = [
            "cache.nixos.org"
            "channels.nixos.org"
          ];
        };
      };
      permissions = {
        deny = [ "Bash(git *)" ];
        allow = [
          "Bash(jj log)"
          "Bash(jj st)"
          "Bash(jj diff)"
          "Bash(jj root)"
        ];
      };
    };
  };
}
