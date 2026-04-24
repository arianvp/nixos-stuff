{ config, ... }:
{
  # Symlink the whole nvim/ directory live into ~/.config/nvim/. Edits and
  # add/remove of files take effect immediately — no `home-manager switch`.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoRoot}/modules/home/nvim";
}
