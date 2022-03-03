self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      silver-searcher
      nixpkgs-fmt
      asciinema
      bitwarden-cli
      cabal2nix
      compton
      ctags
      chromium
      discord
      evince
      firefox
      fzf
      git
      gnupg
      graphviz
      htop
      jq
      neovim
      obs-studio
      pavucontrol
      signal-desktop
      tmux
      tmate
      tmux.man
      transmission-gtk
      vlc
      vscode
      zlib
      pkg-config
      win-virtio
      gmp
      awscli
      ncurses
    ];
  };
}
