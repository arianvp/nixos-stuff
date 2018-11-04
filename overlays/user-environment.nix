self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      ag
      asciinema
      cabal2nix
      ctags
      dmenu
      dzen2
      feh
      feh.man
      firefox
      fzf
      git
      graphviz
      htop
      j4-dmenu-desktop
      jq
      neovim
      compton
      tmux
      tmux.man
      quake3
      obs-studio
      discord
      multimc
    ];
  };
}
