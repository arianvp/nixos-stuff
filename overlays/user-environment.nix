self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      ag
      arandr
      asciinema
      bitwarden-cli
      cabal2nix
      cabal-install
      zoom-us
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
      gnupg
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
      signal-desktop
      tmux
      tmux.man
      transmission-gtk
      vlc
      vscode
      zlib
      pkg-config
      wire-desktop
      gmp
      ncurses
      (haskell.packages.ghc864.ghcWithPackages (p: [
      ]))
    ];
  };
}
