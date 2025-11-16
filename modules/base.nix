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


  nixpkgs.config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) [ "claude-code" ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  users.users.arian = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];

    packages = [
      pkgs.git
      pkgs.nixfmt
      pkgs.btop
      pkgs.nixd
      pkgs.go
      pkgs.binutils
      pkgs.dnsutils
      pkgs.unixtools.netstat
      pkgs.claude-code
    ];
  };
}
