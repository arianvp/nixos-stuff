self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      ag
      asciinema
      cabal2nix
      elm2nix
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
      pavucontrol
      arandr
      transmission-gtk
      jq
      neovim
      compton
      tmux
      tmux.man
      quake3
      evince
      obs-studio
      discord
      multimc
      scrot
      vscode
      cachix
      haskell.compiler.ghc863
      wire-desktop
      cabal-install
      # (import (builtins.fetchTarball https://github.com/domenkozar/hie-nix/tarball/master ) {}).hies

    ];
  };
}
