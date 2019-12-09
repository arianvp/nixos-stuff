self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      ag
      arandr
      nixpkgs-fmt
      asciinema
      bitwarden-cli
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
      taskwarrior
      timewarrior
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
      gnome-builder
      gnome3.glade
      gnome3.gnome-boxes
      scrot
      signal-desktop
      tmux
      tmate
      mono
      tmux.man
      transmission-gtk
      vlc
      vscode
      fsharp
      dotnet-sdk
      zlib
      pkg-config
      wire-desktop
      win-virtio
      gmp
      awscli
      fractal
      ncurses
      (haskell.packages.ghc864.ghcWithPackages (p: [
      ]))
      (import (builtins.fetchTarball "https://github.com/hercules-ci/ghcide-nix/tarball/master") {}).ghcide-ghc844
    ];
  };
}
