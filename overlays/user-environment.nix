self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      tree
      git
      neovim
      jq
      ag
      fzf
      asciinema
      chromium
      graphviz
    ];
  };
}
