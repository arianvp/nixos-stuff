{ home-manager }:
{ lib, ... }:
{
  imports = [ home-manager.darwinModules.home-manager ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "claude-code"
    ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    users.arian = ../home;
  };
}
