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

  # Make sure we don't accidentally use unfree software. Begone!
  vscode = final.vscodium;
}
