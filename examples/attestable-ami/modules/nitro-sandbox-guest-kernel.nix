# A kernel for Nitro Sandbox guests with what a sandbox has and nothing else:
# tinyconfig, plus the devices of
# https://github.com/firecracker-microvm/firecracker/blob/main/docs/nitro-sandboxes/getting-started.md
# (UEFI, ACPI, virtio-pci with the DMB extension, virtio-blk, virtio-net,
# vsock and NSM), and what systemd and the verity store need.
#
# Everything is built in, so there are no modules to load or to trust, and
# lockdown is fixed at build time rather than on the command line.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  base = pkgs.linuxPackages_6_18.kernel;
  patch = pkgs.callPackage ./nitro-sandbox-patch.nix { };

  options = {
    "64BIT" = "y";
    SMP = "y";
    # tinyconfig trades speed and allocator hardening for size.
    CC_OPTIMIZE_FOR_SIZE = "n";
    CC_OPTIMIZE_FOR_PERFORMANCE = "y";
    SLUB_TINY = "n";
    MODULES = "n";

    # UEFI boots the sandbox, which needs an EFI stub, and ACPI describes it.
    EFI = "y";
    EFI_STUB = "y";
    ACPI = "y";
    DMI = "y";
    DMIID = "y";

    # The Nitro hypervisor's paravirtual clock.
    HYPERVISOR_GUEST = "y";
    PARAVIRT = "y";
    KVM_GUEST = "y";
    PARAVIRT_GUEST_CLOCK = "y";

    PCI = "y";
    PCI_MSI = "y";
    VIRTIO_MENU = "y";
    VIRTIO_PCI = "y";
    VIRTIO_BLK = "y";
    NET = "y";
    INET = "y";
    UNIX = "y";
    NETDEVICES = "y";
    NET_CORE = "y";
    VIRTIO_NET = "y";
    VSOCKETS = "y";
    VIRTIO_VSOCKETS = "y";
    # Attestation.
    NSM = "y";

    # Output only, and only in debug mode.
    TTY = "y";
    SERIAL_8250 = "y";
    SERIAL_8250_CONSOLE = "y";
    PRINTK = "y";

    # The drive: a GPT with the store and its verity hashes.
    BLOCK = "y";
    BLK_DEV = "y";
    PARTITION_ADVANCED = "y";
    EFI_PARTITION = "y";
    MD = "y";
    BLK_DEV_DM = "y";
    DM_VERITY = "y";
    MISC_FILESYSTEMS = "y";
    EROFS_FS = "y";
    # /etc, which NixOS mounts as an erofs image from a loop device, under an
    # overlay.
    BLK_DEV_LOOP = "y";
    OVERLAY_FS = "y";

    BLK_DEV_INITRD = "y";
    RD_ZSTD = "y";
    BINFMT_ELF = "y";
    BINFMT_SCRIPT = "y";

    # What systemd needs (system.requiredKernelConfig), and what tinyconfig
    # leaves out of it.
    MULTIUSER = "y";
    FUTEX = "y";
    EPOLL = "y";
    SIGNALFD = "y";
    TIMERFD = "y";
    EVENTFD = "y";
    SHMEM = "y";
    AIO = "y";
    ADVISE_SYSCALLS = "y";
    MEMBARRIER = "y";
    POSIX_TIMERS = "y";
    FILE_LOCKING = "y";
    FHANDLE = "y";
    INOTIFY_USER = "y";
    PROC_FS = "y";
    PROC_SYSCTL = "y";
    SYSFS = "y";
    DEVTMPFS = "y";
    TMPFS = "y";
    TMPFS_POSIX_ACL = "y";
    TMPFS_XATTR = "y";
    AUTOFS_FS = "y";
    CGROUPS = "y";
    NAMESPACES = "y";
    SECCOMP = "y";
    SECCOMP_FILTER = "y";
    CRYPTO_USER_API_HASH = "y";
    CRYPTO_HMAC = "y";
    CRYPTO_SHA256 = "y";

    SECURITY = "y";
    SECURITYFS = "y";
    SECURITY_LOCKDOWN_LSM = "y";
    SECURITY_LOCKDOWN_LSM_EARLY = "y";
    LOCK_DOWN_KERNEL_FORCE_CONFIDENTIALITY = "y";
  };

  configfile = pkgs.stdenv.mkDerivation {
    name = "nitro-sandbox-guest-config";
    inherit (base) src;
    patches = [ patch ];
    postPatch = "patchShebangs scripts";
    nativeBuildInputs = with pkgs.buildPackages; [
      bc
      bison
      flex
      perl
    ];
    makeFlags = [ "ARCH=${pkgs.stdenv.hostPlatform.linuxArch}" ];
    buildPhase = ''
      make $makeFlags tinyconfig
      ${lib.concatMapAttrsStringSep "\n" (
        name: value: "scripts/config --set-val ${name} ${value}"
      ) options}
      make $makeFlags olddefconfig
      # Kconfig drops what it can't satisfy without a word.
      ${lib.concatMapAttrsStringSep "\n" (
        name: value:
        if value == "n" then
          "grep -q '^# CONFIG_${name} is not set$' .config || ! grep -q '^CONFIG_${name}=' .config || { echo 'CONFIG_${name} is set' >&2; exit 1; }"
        else
          "grep -qx 'CONFIG_${name}=${value}' .config || { echo 'CONFIG_${name} is not ${value}' >&2; failed=1; }"
      ) options}
      [ -z "''${failed:-}" ]
    '';
    installPhase = "cp .config $out";
  };

  kernel = pkgs.linuxManualConfig {
    inherit (base) version modDirVersion src;
    inherit configfile;
    kernelPatches = [
      {
        name = "nitro-sandbox";
        inherit patch;
      }
    ];
    config = lib.mapAttrs' (name: lib.nameValuePair "CONFIG_${name}") options;
  };
in
{
  boot.kernelPackages = pkgs.linuxPackagesFor kernel;

  # Built in.
  boot.initrd.includeDefaultModules = false;
  boot.initrd.availableKernelModules = lib.mkForce [ ];
  boot.initrd.kernelModules = lib.mkForce [ ];
  boot.kernelModules = lib.mkForce [ ];
  # aggregateModules means to accept a kernel without modules, but buildEnv
  # creates lib/modules regardless, and depmod then fails on the missing
  # kernel version. An empty tree for this kernel satisfies it.
  system.modulesTree = lib.mkForce [
    (pkgs.runCommand "no-modules" { } ''
      mkdir -p $out/lib/modules/${kernel.modDirVersion}
      cd $out/lib/modules/${kernel.modDirVersion}
      touch modules.order modules.builtin modules.cer
    '')
  ];
}
