{ lib, nodes, ... }:
{
  name = "bootloader";
  nodes.machine = {
    imports = [ ./bootloader.nix ];
    # virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    system.switch.enable = true;
    boot.loader.nixos-stuff.enable = true;

    virtualisation.fileSystems."/boot" = {
      fsType = "tmpfs";
    };
  };

  # TODO: Actually have the bootloader used in tests
  testScript = ''
    machine.succeed("${lib.getExe nodes.machine.system.build.installBootLoader}")
    machine.succeed("updatectl list")
  '';
}
