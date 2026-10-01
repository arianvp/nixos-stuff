{ pkgs, lib, ... }:
let
  jj-stack = pkgs.callPackage ../../../packages/jj-stack/package.nix { };
  completion =
    shell:
    pkgs.runCommand "jj-stack-completion.${shell}" { } ''
      ${lib.getExe jj-stack} completion ${shell} --jj-alias stack > $out
    '';
in
{
  home.packages = [ jj-stack ];

  programs.zsh.initContent = "source ${completion "zsh"}";
  programs.bash.initExtra = "source ${completion "bash"}";

  programs.claude-code = {
    skills.jj-stack = jj-stack.skill;
    settings.permissions.ask = [
      "Bash(jj-stack submit*)"
      "Bash(jj-stack sub *)"
      "Bash(jj-stack merge*)"
      "Bash(jj-stack sync*)"
      "Bash(jj-stack unstack*)"
      "Bash(jj-stack cleanup*)"
      "Bash(jj stack submit*)"
      "Bash(jj stack sub *)"
      "Bash(jj stack merge*)"
      "Bash(jj stack sync*)"
      "Bash(jj stack unstack*)"
      "Bash(jj stack cleanup*)"
    ];
  };
}
