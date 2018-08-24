self: super: {
  neovim = super.neovim.override {
    configure = {
      customRC = ''
      set expandtab
      set shiftwidth=2
      set softtabstop=2
      '';
      packages.myPackages = with self.vimPlugins; {
        start = [ fugitive fzfWrapper fzf-vim  vim-nix ];
      };
    };
  };
}
