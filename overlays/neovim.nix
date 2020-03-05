self: super: {
  neovim = super.neovim.override {
    configure = {
      customRC = ''
        set expandtab
        set shiftwidth=2
        set softtabstop=2
        set bg=light
        set undofile
        set ignorecase
        set smartcase
        set mouse=a
        autocmd BufWritePre * %s/\s\+$//e
        map <C-p> :Files<CR>
        map <C-a> :Ag<CR>
        map <C-n> :NERDTreeToggle<CR>
        map <C-t> :TagbarToggle<CR>
        let g:ctrlp_user_command = ['.git/', 'git --git-dir=%s/.git ls-files -oc --exclude-standard']
        tnoremap <Esc> <C-\><C-n>
      '';
      packages.myPackages = with self.vimPlugins; {
        start = [ tagbar nerdtree fugitive fzfWrapper fzf-vim vim-jsonnet vim-nix vim-terraform vim-tmux-navigator ];
      };
    };
  };
}
