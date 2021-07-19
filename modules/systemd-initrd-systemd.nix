{ config, lib, pkgs, modulesPath, ... }:

# with utils;
with lib;
    #"rc-local.service"
with import (modulesPath + "/system/boot/systemd-unit-options.nix") { inherit config lib; };
with import (modulesPath + "/system/boot/systemd-lib.nix") { inherit lib pkgs; config = config.boot.initrd; };
let
  cfg = config.boot.initrd.systemd;

  upstreamUnits = [
    "basic.target"
    "blockdev@.target"
    "boot-complete.target"
    "console-getty.service"
    "cryptsetup-pre.target"
    "cryptsetup.target"
    "debug-shell.service"
    "dev-hugepages.mount"
    "dev-mqueue.mount"
    "emergency.service"
    "emergency.target"
    "exit.target"
    "final.target"
    "getty-pre.target"
    "getty.target"
    "getty@.service"
    "halt.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "initrd-cleanup.service"
    "initrd-fs.target"
    "initrd-parse-etc.service"
    "initrd-root-device.target"
    "initrd-root-fs.target"
    "initrd-switch-root.service"
    "initrd-switch-root.target"
    "initrd-udevadm-cleanup-db.service"
    "initrd.target"
    "kexec.target"
    # "kmod-static-nodes.service"
    #"ldconfig.service"
    "local-fs-pre.target"
    "local-fs.target"
    "modprobe@.service"
    "nss-lookup.target"
    "nss-user-lookup.target"
    "paths.target"
    "poweroff.target"
    "printer.target"
    "proc-sys-fs-binfmt_misc.automount"
    "proc-sys-fs-binfmt_misc.mount"
    #"quotaon.service"
    "reboot.target"
    "rescue.service"
    "rescue.target"
    "rpcbind.target"
    "serial-getty@.service"
    "shutdown.target"
    "sigpwr.target"
    "sleep.target"
    "slices.target"
    "smartcard.target"
    "sockets.target"
    "sound.target"
    "suspend-then-hibernate.target"
    "suspend.target"
    "swap.target"
    "sys-fs-fuse-connections.mount"
    "sys-kernel-config.mount"
    "sys-kernel-debug.mount"
    "sys-kernel-tracing.mount"
    "sysinit.target"
    "syslog.socket"
    # NOTE: multiple layers of escaping going on here. scary
    "system-systemd\\\\x2dcryptsetup.slice"
    "systemd-ask-password-console.path"
    "systemd-ask-password-console.service"
    "systemd-ask-password-wall.path"
    "systemd-ask-password-wall.service"
    "systemd-backlight@.service"
    "systemd-binfmt.service"
    "systemd-coredump.socket"
    "systemd-coredump@.service"
    "systemd-exit.service"
    "systemd-fsck-root.service"
    "systemd-fsck@.service"
    "systemd-halt.service"
    "systemd-hibernate-resume@.service"
    "systemd-hibernate.service"
    # "systemd-homed-activate.service"
    # "systemd-homed.service"
    "systemd-hostnamed.service"
    "systemd-hwdb-update.service"
    "systemd-hybrid-sleep.service"
    # "systemd-initctl.service"
    # "systemd-initctl.socket"
    "systemd-journal-catalog-update.service"
    "systemd-journal-flush.service"
    "systemd-journald-audit.socket"
    "systemd-journald-dev-log.socket"
    "systemd-journald-varlink@.socket"
    "systemd-journald.service"
    "systemd-journald.socket"
    "systemd-journald@.service"
    "systemd-journald@.socket"
    "systemd-kexec.service"
    "systemd-machine-id-commit.service"
    "systemd-modules-load.service"
    # "systemd-portabled.service"
    "systemd-poweroff.service"
    "systemd-pstore.service"
    # "systemd-quotacheck.service"
    "systemd-random-seed.service"
    "systemd-reboot.service"
    "systemd-remount-fs.service"
    # TODO: systemd-repart gets disabled when importd is disabled due to implicit dependency in openssl. urfgh
    # "systemd-repart.service"
    "systemd-resolved.service"
    "systemd-rfkill.service"
    "systemd-rfkill.socket"
    "systemd-suspend-then-hibernate.service"
    "systemd-suspend.service"
    "systemd-sysctl.service"
    # "systemd-sysusers.service"
    "systemd-tmpfiles-clean.service"
    "systemd-tmpfiles-clean.timer"
    "systemd-tmpfiles-setup-dev.service"
    "systemd-tmpfiles-setup.service"
    "systemd-udev-settle.service"
    "systemd-udev-trigger.service"
    "systemd-udevd-control.socket"
    "systemd-udevd-kernel.socket"
    "systemd-udevd.service"
    # "systemd-update-utmp-runlevel.service"
    "systemd-update-utmp.service"
    "systemd-vconsole-setup.service"
    "systemd-volatile-root.service"
    "time-set.target"
    "time-sync.target"
    "timers.target"
    "tmp.mount"
    "umount.target"
    "usb-gadget.target"

  ];

  upstreamWants = [

    # FIXME: Only added this because the upstream systemd module in NixOS
    # contains completely non-sensical code that makes local-fs.target depend
    # on multi-user.target ??? Add patch upstream
    "multi-user.target.wants"

    "sysinit.target.wants"
    "sockets.target.wants"
    "local-fs.target.wants"
    # TODO: systemd-repart
    # "initrd-root-fs.target.wants"
  ];

  systemd = cfg.package;

  commonUnitText = def: ''
    [Unit]
    ${attrsToSection def.unitConfig}
  '';

  targetToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def;
    };

  serviceToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def + ''
        [Service]
        ${let
        env = def.environment;
      in
        concatMapStrings (
          n:
            let
              s = optionalString (env.${n} != null)
                "Environment=${builtins.toJSON "${n}=${env.${n}}"}\n";
              # systemd max line length is now 1MiB
              # https://github.com/systemd/systemd/commit/e6dde451a51dc5aaa7f4d98d39b8fe735f73d2af
            in
              if stringLength s >= 1048576 then throw "The value of the environment variable ‘${n}’ in systemd service ‘${name}.service’ is too long." else s
        ) (attrNames env)}
        ${attrsToSection def.serviceConfig}
      '';
    };

  socketToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def + ''
        [Socket]
        ${attrsToSection def.socketConfig}
      '';
    };

  timerToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def + ''
        [Timer]
        ${attrsToSection def.timerConfig}
      '';
    };

  pathToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def + ''
        [Path]
        ${attrsToSection def.pathConfig}
      '';
    };

  mountToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def + ''
        [Mount]
        ${attrsToSection def.mountConfig}
      '';
    };

  automountToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def + ''
        [Automount]
        ${attrsToSection def.automountConfig}
      '';
    };

  sliceToUnit = name: def:
    {
      inherit (def) aliases wantedBy requiredBy enable;
      text = commonUnitText def + ''
        [Slice]
        ${attrsToSection def.sliceConfig}
      '';
    };

in

{
  options.boot.initrd = {

    systemd.package = mkOption {
      default = pkgs.systemdInitrd;
      defaultText = "pkgs.systemdInitrd";
      type = types.package;
      description = "The systemd package.";
    };

    systemd.units = mkOption {
      description = "Definition of systemd units.";
      default = {};
      type = with types; attrsOf (
        submodule (
          { name, config, ... }:
            {
              options = concreteUnitOptions;
              config = {
                unit = mkDefault (makeUnit name config);
              };
            }
        )
      );
    };

    systemd.packages = mkOption {
      default = [];
      type = types.listOf types.package;
      example = literalExample "[ pkgs.systemd-cryptsetup-generator ]";
      description = "Packages providing systemd units";
    };

    systemd.defaultUnit = mkOption {
      default = "initrd.target";
      type = types.str;
      example = literalExample "initrd.target";
      description = "Default unit to start";
    };

    systemd.ctrlAltDelUnit = mkOption {
      default = "reboot.target";
      type = types.str;
      example = literalExample "reboot.target";
      description = "Default unit to start";
    };

    systemd.targets = mkOption {
      default = {};
      type = with types; attrsOf (submodule [ { options = targetOptions; } ]);
      description = "Definition of systemd target units.";
    };

    systemd.services = mkOption {
      default = {};
      type = with types; attrsOf (submodule { options = serviceOptions; });
      description = "Definition of systemd service units.";
    };

    systemd.sockets = mkOption {
      default = {};
      type = with types; attrsOf (submodule [ { options = socketOptions; } ]);
      description = "Definition of systemd socket units.";
    };

    systemd.timers = mkOption {
      default = {};
      type = with types; attrsOf (submodule [ { options = timerOptions; } ]);
      description = "Definition of systemd timer units.";
    };

    systemd.paths = mkOption {
      default = {};
      type = with types; attrsOf (submodule [ { options = pathOptions; } ]);
      description = "Definition of systemd path units.";
    };

    systemd.mounts = mkOption {
      default = [];
      type = with types; listOf (submodule { options = mountOptions; });
      description = ''
        Definition of systemd mount units.
        This is a list instead of an attrSet, because systemd mandates the names to be derived from
        the 'where' attribute.
      '';
    };

    systemd.automounts = mkOption {
      default = [];
      type = with types; listOf (submodule { options = automountOptions; });
      description = ''
        Definition of systemd automount units.
        This is a list instead of an attrSet, because systemd mandates the names to be derived from
        the 'where' attribute.
      '';
    };

    systemd.slices = mkOption {
      default = {};
      type = with types; attrsOf (submodule [ { options = sliceOptions; } ]);
      description = "Definition of slice configurations.";
    };

    systemd.generators = mkOption {
      type = types.attrsOf types.path;
      default = {};
      example = { systemd-gpt-auto-generator = "/dev/null"; };
      description = ''
        Definition of systemd generators.
        For each <literal>NAME = VALUE</literal> pair of the attrSet, a link is generated from
        <literal>/etc/systemd/system-generators/NAME</literal> to <literal>VALUE</literal>.
      '';
    };

    systemd.tmpfiles.rules = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "d /tmp 1777 root root 10d" ];
      description = ''
        Rules for creating and cleaning up temporary files
        automatically. See
        <citerefentry><refentrytitle>tmpfiles.d</refentrytitle><manvolnum>5</manvolnum></citerefentry>
        for the exact format.
      '';
    };

  };


  ###### implementation

  config = {

    system.build.initrdUnits = generateUnits "system" cfg.units upstreamUnits upstreamWants;

    # TODO: Our patches completely b0rk systemd early boot.
    # systemd-tmpfiles-setup-dev should happen BEFORE udev even is started or
    # REALLY BAD THINGS happen. Yet we delay it all the way to multi-user for
    # nixops send-keys?
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/systemd/default.nix#L486-L490
    boot.initrd.systemd.services.systemd-tmpfiles-setup-dev.wantedBy = [ "sysinit.target" ];


    # TODO: Remove once we patched nixpkgs
    boot.initrd.systemd.services.kmod-static-nodes = {
      wantedBy = [ "sysinit.target" ];
      unitConfig = {
        Before = [ "sysinit.target" "systemd-tmpfiles-setup-dev.service" ];
        DefaultDependencies = "no";
        ConditionCapability = "CAP_SYS_MODULE";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${pkgs.kmod}/bin/kmod static-nodes --format=tmpfiles --output=/run/tmpfiles.d/static-nodes.conf";
      };
    };


    boot.initrd.systemd.units =
      mapAttrs' (n: v: nameValuePair "${n}.path" (pathToUnit n v)) cfg.paths
      // mapAttrs' (n: v: nameValuePair "${n}.service" (serviceToUnit n v)) cfg.services
      // mapAttrs' (n: v: nameValuePair "${n}.slice" (sliceToUnit n v)) cfg.slices
      // mapAttrs' (n: v: nameValuePair "${n}.socket" (socketToUnit n v)) cfg.sockets
      // mapAttrs' (n: v: nameValuePair "${n}.target" (targetToUnit n v)) cfg.targets
      // mapAttrs' (n: v: nameValuePair "${n}.timer" (timerToUnit n v)) cfg.timers
      // listToAttrs (
        map
          (
            v: let
              n = escapeSystemdPath v.where;
            in
              nameValuePair "${n}.mount" (mountToUnit n v)
          ) cfg.mounts
      )
      // listToAttrs (
        map
          (
            v: let
              n = escapeSystemdPath v.where;
            in
              nameValuePair "${n}.automount" (automountToUnit n v)
          ) cfg.automounts
      );

  };

}
