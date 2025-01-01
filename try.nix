import ./nixos {
  configuration =
    {
      config,
      pkgs,
      lib,
      modulesPath,
      ...
    }:
    let
      extlinux-conf-builder =
        import (modulesPath + "/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.nix")
          {
            pkgs = pkgs.buildPackages;
          };
    in
    {
      nixpkgs.crossSystem = {
        system = "armv7l-linux";
      };
      nixpkgs.overlays = [
        (self: super: {
          # Does not cross-compile...
          alsa-firmware = super.runCommandNoCC "neutered-firmware" { } "mkdir -p $out";

          # A "regression" in nixpkgs, where python3 pycryptodome does not cross-compile.
          crda = super.runCommandNoCC "neutered-crda" { } "mkdir -p $out";

        })
      ];
      imports = [
        # (modulesPath + "/installer/cd-dvd/sd-image-armv7l-multiplatform.nix")
        (modulesPath + "/installer/cd-dvd/sd-image.nix")
        (modulesPath + "/profiles/minimal.nix")
        # (modulesPath + "/profiles/installation-device.nix")
        # (modulesPath + "/installer/cd-dvd/sd-image.nix")
      ];
      boot.loader.grub.enable = false;
      # boot.supportedFilesystems = lib.mkForce [ "vfat" ];
      boot.enableContainers = lib.mkForce false;
      security.polkit.enable = lib.mkForce false;
      services.udisks2.enable = false; # Investigate
      documentation.nixos.enable = lib.mkForce false;
      documentation.enable = lib.mkForce false;

      boot.kernelParams = [
        "console=ttyS0,115200n8"
        "console=ttymxc0,115200n8"
        "console=ttyAMA0,115200n8"
        "console=ttyO0,115200n8"
        "console=ttySAC2,115200n8"
        "console=tty0"
      ];

      sdImage.compressImage = false;

      # TODO: extlinux
      sdImage.populateRootCommands = ''
        mkdir -p ./files/boot
        ${extlinux-conf-builder} -t 3 -c ${config.system.build.toplevel} -d ./files/boot
      '';
      sdImage.populateFirmwareCommands = "
      echo hello > firmware/config.txt
    ";

      system.build.orangePiSdImage = pkgs.runCommand "libre" { uboot_position = 8; } ''
        device="${config.sdImage.imageName}"
        cp ${config.system.build.sdImage}/sd-image/${config.sdImage.imageName} $device
        chmod +w $device
        uboot=${pkgs.pkgsCross.armv7l-hf-multiplatform.ubootOrangePiOne}/u-boot-sunxi-with-spl.bin
        echo "u-boot fusing"
        dd if=$uboot of=$device conv=notrunc seek=$uboot_position bs=1024
        mkdir -p $out
        cp $device $out

      '';
      # Fuses in the evil XU4 SecureBoot bootloader to the first few disk sectors
      system.build.sdImageWithEvilFirmware =
        pkgs.runCommand "evil"
          {
            signed_bl1_position = 1;
            bl2_position = 31;
            uboot_position = 63;
            tzsw_position = 2111;
          }
          ''
            device="${config.sdImage.imageName}-evil.img"
            cp ${config.system.build.sdImage}/sd-image/${config.sdImage.imageName} $device
            chmod +w $device
          '';
    };
}
