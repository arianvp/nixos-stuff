{pkgs, lib, ...}:
{
  programs.jujutsu.settings = {
    fix.tools = {
      "20-gofmt" = {
        command = [
          (lib.getExe' pkgs.go "gofmt")
          "-s"
        ];
        patterns = [ "glob:'**/*.go'" ];
      };
    };
  };
}
