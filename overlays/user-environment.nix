self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      ag
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
      gnome-builder
      gnome3.glade
      gnome3.gnome-boxes
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
