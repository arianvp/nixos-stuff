{pkgs, lib, ...}:
{
  programs.jujutsu.settings.fix.tools = {
    "20-nixfmt" = {
      command = [ (lib.getExe pkgs.nixfmt) ];
      patterns = [ "glob:'**/*.nix'" ];
    };
    # useful for nixpkgs conflicts. runs in treefmt in nixpkgs too
    "80-keep-sorted" = {
      command = [ (lib.getExe pkgs.keep-sorted) "-" ];
      patterns = [ "glob:'**/*'" ];
    };
    "00-statix" = {
      command = [
        (lib.getExe pkgs.statix)
        "fix"
        "-s"
      ];
      patterns = [ "glob:'**/*.nix'" ];
      enabled = false;
    };
  };
}
