self: super: {
  user-environment = self.buildEnv {
    name = "my-user-environment";
    paths = with self; [
      git
      neovim
      jq
      ag
      fzf
      cabal2nix
    ];
  };
}
