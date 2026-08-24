pkgs: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      doctl
      opentofu
      dnscontrol
    ];
  };
}
