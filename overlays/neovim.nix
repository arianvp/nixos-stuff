self: super: {
  neovim = super.neovim.override {
    configure = {
      customRC = ''
        set expandtab
        set shiftwidth=2
        set softtabstop=2
        set undofile
        set mouse=a
        map <C-p> :FZF
        map <C-a> :Ag 
        map <C-n> :NERDTreeToggle<CR>
        map <C-t> :TagbarToggle<CR>
        let g:ctrlp_user_command = ['.git/', 'git --git-dir=%s/.git ls-files -oc --exclude-standard']
        tnoremap <Esc> <C-\><C-n>
      '';
      packages.myPackages = with self.vimPlugins; {
        start = [ tagbar nerdtree fugitive fzfWrapper fzf-vim  vim-nix ];
      };
    };
  };
}
