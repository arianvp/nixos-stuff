{
  lib,
  pkgs,
  config,
  isLinux,
  ...
}:
{

  imports = [
    ./jj
    ./nvim.nix
    ./claude-code.nix
  ]
  ++ lib.optionals isLinux [
    ./linux.nix
  ];

  # This option is purely a flake workaround. In a flake, relative-path syntax
  # like `./foo` resolves to a /nix/store copy of the flake source, so passing
  # it to `mkOutOfStoreSymlink` produces a link to the store instead of a live
  # file. We have to name the on-disk checkout path explicitly as a string.
  # If we ever move off flakes, this option can go — `./foo` would just work.
  options.repoRoot = lib.mkOption {
    type = lib.types.path;
    apply = toString;
    default = "${config.home.homeDirectory}/Projects/nixos-stuff";
    description = ''
      Absolute path to this repo's working copy. Used by modules that want to
      `mkOutOfStoreSymlink` a file from the repo into the home dir so edits
      take effect without a `home-manager switch`. Override per-host if the
      repo lives somewhere else.
    '';
  };

  config = {
    programs.bash.enable = true;
    programs.direnv.enable = true;
    programs.git.enable = true;

    home.packages = with pkgs; [
      ripgrep
      binutils
      btop
      ijq
      jq
    ];

    home.stateVersion = "26.05";
  };
}
