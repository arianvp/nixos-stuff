{ config, pkgs, ... }:
{
  # `programs.neovim` would try to manage `~/.config/nvim/init.lua` itself,
  # which conflicts with the live-symlink of the whole nvim/ directory below.
  # Install the package directly and wire up EDITOR + the vim alias by hand.
  home.packages = [ pkgs.neovim ];
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
  home.shellAliases.vim = "nvim";

  # Symlink the whole nvim/config/ directory live into ~/.config/nvim/. Edits
  # and add/remove of files take effect immediately — no `home-manager switch`.
  # The lua lives in its own subdirectory so this module's default.nix does not
  # end up inside ~/.config/nvim.
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.repoRoot}/modules/home/nvim/config";
}
