self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      firefox
      ctags
      htop
      git
      neovim
      jq
      ag
      fzf
      cabal2nix
      asciinema
      firefox
      graphviz
      tmux
    ];
  };
}
