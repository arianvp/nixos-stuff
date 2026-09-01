{
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
  programs.git.ignores = [ ".direnv" ];
}
