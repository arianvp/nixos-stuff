self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      (aspellWithDicts (ps : [ps.en]))
      ag
      arandr
      asciinema
      cabal2nix
      cabal-install
      chromium
      compton
      ctags
      discord
      dmenu
      dzen2
      elm2nix
      evince
      feh
      feh.man
      firefox
      fzf
      git
      graphviz
      htop
      j4-dmenu-desktop
      jq
      libreoffice
      multimc
      neovim
      obs-studio
      pavucontrol
      scrot
      tmux
      tmux.man
      transmission-gtk
      vlc
      vscode
      wire-desktop
      (haskell.packages.ghc844.ghcWithPackages (p: [
      ]))
    ];
  };
}
