{ pkgs, lib, ... }:
{
  programs.claude-code = {
    enable = true;
    settings = {
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
