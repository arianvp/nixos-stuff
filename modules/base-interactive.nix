{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./diff.nix
    ./dnssd.nix
    ./monitoring.nix
    ./nix.nix
    ./ssh.nix
  ];

  documentation.man = {
    enable = true;
    cache.enable = true;
  };

  programs.direnv.enable = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = false;
    vimAlias = true;
  };

  environment.systemPackages = [ pkgs.ghostty.terminfo ];

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "nix-trusted-users"
    ];
    packages = builtins.attrValues {
      inherit (pkgs)
        binutils
        btop
        dnsutils
        ghostty
        git
        go
        gopls
        ijq
        jjui
        jujutsu
        jq
        nixd
        nixfmt
        tig
        tmux
        zed-editor
        ;
    };
  };
}
