{ config, ... }:
{

  imports = [
    ./watchman.nix
    ./nix.nix
    ./go.nix
  ];

  programs.jjui.enable = true;
  programs.jujutsu.enable = true;

  # Symlink the whole conf.d/ directory live into ~/.config/jj/conf.d/. Both
  # edits and add/remove of drop-in files take effect immediately — no
  # `home-manager switch` needed.
  xdg.configFile."jj/conf.d".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoRoot}/modules/home/jj/conf.d";
}
