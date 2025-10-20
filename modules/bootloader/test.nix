{

  nodes.machine = {
    imports = [ ./bootloader.nix ];
    virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    system.switch.enable = true;
    boot.loader.nixos-stuff.enable = true;
  };

  testScript = ''

  '';
}
