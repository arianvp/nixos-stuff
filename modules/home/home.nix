{ lib, pkgs, config, ... }:
{

  imports = [
    ./jj
    ./nvim.nix
    ./claude-code.nix
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
    programs.noctalia-shell = {
      systemd.enable = true;
      settings = {
      };
      # this may also be a string or a path to a JSON file.
    };

    programs.direnv.enable = true;

    home.packages = [ pkgs.claude-code pkgs.sshfs ];

    systemd.user = {
      automounts.home-arian-altra = {
        Automount.Where = "/home/arian/altra";
        Install.WantedBy = [ "default.target" ];
      };
      mounts.home-arian-altra.Mount = {
        Where = "/home/arian/altra";
        What = "arian@altra.ygg.nixos.sh:/home/arian";
        Type = "fuse.sshfs";
        Options = "_netdev,user,delay_connect,reconnect,ServerAliveInterval=15,dir_cache=yes,idmap=user,follow_symlinks,transform_symlinks,compression=yes";
      };
    };

    home.stateVersion = "26.05";
  };
}
