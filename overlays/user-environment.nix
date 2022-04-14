self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      silver-searcher
      nixpkgs-fmt
      evince
      firefox
      fzf
      git
      gnupg
      graphviz
      htop
      jq
      neovim
      vscode
    ];
  };
}
