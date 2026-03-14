{ pkgs, lib, ... }:
{
  programs.claude-code = {
    enable = true;

    settings = {
      hooks = {
      };
  };
}
