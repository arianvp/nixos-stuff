final: prev: {
  vscodium = prev.vscode-with-extensions.override {
    vscode = prev.vscodium;
    vscodeExtensions = with prev.vscode-extensions; [
      vscodevim.vim
      # hashicorp.terraform
      haskell.haskell
      redhat.vscode-yaml
      golang.Go
    ];
  };

  vscodiumOrig = prev.vscodium;

}
