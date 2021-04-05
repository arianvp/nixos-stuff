prev: final: {
  vscodium = prev.vscode-with-extensions.override {
    vscode = prev.vscodium;
    vscodeExtensions = with prev.vscode-extensions; [
    	ms-kubernetes-tools.vscode-kubernetes-tools
    ];
  };

  # Make sure we don't accidentally use unfree software. Begone!
  vscode = final.vscodium;
}
