{ config, pkgs, lib, options, modulesDir, ... }:
let
  makeInitrd =
    { storeContents }:
    pkgs.stdenv.mkDerivation {
      name = "initrd";
      nativeBuildInputs = [ pkgs.cpio ];
      buildCommand = ''
        closureInfo=${pkgs.closureInfo { rootPaths = storeContents; }}
        mkdir root
        mkdir -p $out

        path=$(realpath root)

        cp $closureInfo/registration root/nix-path-registration
        find $(cat $closureInfo/store-paths) | cpio --make-directories --pass-through $path
        (cd ${storeContents} && (find . | cpio --make-directories --pass-through $path))

        (cd $path && (find . | cpio -R +0:+0 -o -H newc | gzip > $out/initrd))

      '';
    };
  cfg = config.boot.initrd;
in
{
  imports = [ ./systemd-initrd-systemd.nix ];
  options.boot = {
    # NOTE: systemd-boot module sets this option. However we completely ignore it =)
    loader.supportsInitrdSecrets = lib.mkOption { type = lib.bool; };

    # TODO: services.udev somehow depends on this. bit of a weird dependency loop.
    # adding this as a workaround
    initrd.extraUdevRulesCommands = lib.mkOption { type = lib.lines; };

    initrd = {

      enable = lib.mkEnableOption "initrd";

      # Emulates the system/boot/luksroot.nix module partially with systemd primitives
      # Only supports the features I am currently using I am afraid.

    };
  };
  disabledModules = [
    "system/boot/stage-1.nix"

    # Requires extraUtilsCommands and sytemd comes with its own cryptsetup mechanisms!
    "system/boot/luksroot.nix"
    # Not supported for now
    "tasks/encrypted-devices.nix"

    "system/boot/initrd-openvpn.nix"
    "system/boot/initrd-ssh.nix"
    "system/boot/initrd-network.nix"
    "system/boot/grow-partition.nix"

    # TODO: Uses extraUdevRulesCommands which we don't want to support (weird imperative interface)
    "tasks/lvm.nix"
    "tasks/swraid.nix"
    "tasks/swraid.nix"
    "tasks/bcache.nix"
    "tasks/filesystems/bcachefs.nix"
    "tasks/filesystems/btrfs.nix"
    "tasks/filesystems/cifs.nix"
    "tasks/filesystems/ecryptfs.nix"
    "tasks/filesystems/exfat.nix"
    "tasks/filesystems/ext.nix"
    "tasks/filesystems/f2fs.nix"
    "tasks/filesystems/glusterfs.nix"
    "tasks/filesystems/jfs.nix"
    "tasks/filesystems/nfs.nix"
    "tasks/filesystems/ntfs.nix"
    "tasks/filesystems/reiserfs.nix"
    "tasks/filesystems/unionfs-fuse.nix"
    "tasks/filesystems/vboxsf.nix"
    "tasks/filesystems/vfat.nix"
    "tasks/filesystems/xfs.nix"
    "tasks/filesystems/zfs.nix"


    # TODO: Uses extraUtilsCommands which we don't want to support (weird imperative interface)
    # "tasks/lvm.nix"
    "system/boot/plymouth.nix"
    "config/console.nix"

    # TODO: implement initrd prepend
    "hardware/cpu/intel-microcode.nix"
    "hardware/cpu/amd-microcode.nix"

    # TODO: bootloader setting path is different
    # "hardware/video/hidpi.nix"

    "virtualisation/virtualbox-guest.nix"

    "services/network-filesystems/nfsd.nix"
    "services/x11/display-managers/xpra.nix"
    "services/networking/iscsi/root-initiator.nix"
  ];
  config = {
    boot.initrd.systemd = {

      services.debug-shell.environment = {
        PATH = "${pkgs.util-linuxMinimal}/bin:${pkgs.busybox}/bin:${config.boot.initrd.systemd.package}/bin:${pkgs.strace}/bin";
      };

      # Not sure if needed anymore? But nixos initrd does this as well. keeping
      services.modprobe-init = {
        wantedBy = [ "sysinit.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig.ExecStart = ''${pkgs.busybox}/bin/ash -c "echo ${pkgs.kmod}/bin/modprobe > /proc/sys/kernel/modprobe"'';
      };

    };

    # TODO: Why is there a hard dependency from systemd-boot to ths? Odd
    system.build.initialRamdiskSecretAppender = pkgs.writeShellScriptBin "append-initrd-secrets"
      ''
        echo unsupported
        exit 0
      '';
    system.build.initialFS =
      let
        modulesClosure = pkgs.makeModulesClosure {
          rootModules = cfg.kernelModules ++ cfg.availableKernelModules;
          kernel = config.system.build.kernel;
          firmware = config.system.build.kernel; # TODO: firmware?
          allowMissing = false;
        };

        modulesConf = pkgs.writeText "modules.conf" (pkgs.lib.strings.intersperse "\n" cfg.kernelModules);

        systemd = cfg.systemd.package;

        passwd = pkgs.writeText "passwd" ''
          root:x:8:8::/root:${pkgs.runtimeShell}"
        '';
        shadow = pkgs.writeText "shadow" ''
          root:x::
        '';
        # NOTE: Without the lvm2 udev rules; for some reason systemd doesn't mount the encrypted volume
        rules = pkgs.symlinkJoin {
          name = "rules";
          paths = [ systemd pkgs.devicemapper ];
        };

      in
      pkgs.linkFarm "initrdfs" [
        { name = "etc/initrd-release"; path = "${config.environment.etc.os-release.source}"; }
        { name = "init"; path = "${systemd}/lib/systemd/systemd"; }
        # TODO: Fix systemd kmod path in nixos systemd package. We patch  kmod
        # to look in this path (and also /lib/modules) but we patched systemd
        # to only look into /run/booted-system. We should patch systemd to look
        # in all the folders kmod is looking
        { name = "lib/modules"; path = "${modulesClosure}/lib/modules"; }
        # TODO: No firmware for now
        # { name ="lib/firmware"; path = "${modulesClosure}/lib/firmware"; }
        { name = "sbin/modprobe"; path = "${pkgs.kmod}/bin/modprobe"; }

        { name = "etc/passwd"; path = "${passwd}"; }
        { name = "etc/shadow"; path = "${shadow}"; }

        # systemd paths
        # TODO: Make configurable and extendable with module system later!
        { name = "etc/modules-load.d/modules.conf"; path = "${modulesConf}"; }

        # NOTE: For some weird reason NixOS systemd package installs most config
        # files in a folder called "example" instead of lib.  It then copies
        # out files from there to /etc/systemd using the nixos module system.
        # All config files _Except for_ udev and networkd live there.  And
        # NixOS always reads from ${systemd}/lib/udev. It's all extremely
        # inconsistent =)

        # udev rules
        { name = "etc/udev"; path = "${rules}/lib/udev"; }
        # NOTE: udev reads link files here
        { name = "etc/systemd/network"; path = "${systemd}/lib/systemd/network"; }

        { name = "etc/systemd/system"; path = "${config.system.build.initrdUnits}"; }
        # { name = "etc/systemd/system"; path = "${systemd}/example/systemd/system"; }

        { name = "etc/sysctl.d"; path = "${systemd}/example/sysctl.d"; }
        { name = "etc/tmpfiles.d"; path = "${systemd}/example/tmpfiles.d"; }

        # NOTE: This module is disabled at compile time on NixOS (we have the system users perl script instead of this)
        # { name = "etc/sysusers.d"; path = "${systemd}/example/sysusers.d"; }

      ];

    boot.kernelParams = [
    ];

    system.build.initialRamdisk = makeInitrd { storeContents = config.system.build.initialFS; };

    # This is here for debugging. So that you can quickly test out the initrd
    system.build.runvm = pkgs.writeShellScriptBin "runvm"
      ''
        exec qemu-kvm -m 1024 -device qemu-xhci -device usb-kbd -kernel ${config.system.build.toplevel}/kernel -initrd ${config.system.build.toplevel}/initrd -append "$(cat ${config.system.build.toplevel}/params)"

      '';

    boot.initrd.availableKernelModules = [

      # Needed for systemd
      "dm_mod"
      "dm_crypt"
      "dm_verity"
      "autofs4"
      "squashfs"
      "overlay"
      "af_packet"

      "crc32c"
      "btrfs"

      # Add nvme modprobe
      "nvme"

      "cryptd"

      # Needed for LUKS on 5.10; but didn't need in 5.4. odd
      "aes"
      "aes_generic"
      "xts"
      "cbc"

      # Needed for systemd-gpt-auto-generator
      "efivars"
      "efivarfs"
      "efi_pstore"

      # QEMU
      "virtio_pci"
      "virtio_blk"
      "virtio_mmio"
      "virtio_console"
      "virtio_balloon"
      "virtio_rng"

      # Keyboard
      "atkbd"
      "ehci_hcd"
      "ehci_pci"
      "hid_apple"
      "hid_generic"
      "hid_lenovo"
      "hid_logitech_dj"
      "hid_logitech_hidpp"
      "hid_microsoft"
      "hid_roccat"
      "i8042"
      "ohci_hcd"
      "ohci_pci"
      "pcips2"
      "sdhci_pci"
      "uhci_hcd"
      "usbhid"
      "xhci_hcd"
      "xhci_pci"
    ];
  };
}
