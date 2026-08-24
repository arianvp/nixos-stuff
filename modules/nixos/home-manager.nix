{ home-manager }:
{ lib, ... }:
{
  imports = [ home-manager.nixosModules.home-manager ];

  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-unwrapped"
      "claude-code"
    ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-bak";
    users.arian = lib.modules.importApply ../home/home.nix { isLinux = true; };
  };
}
