{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.boot.loader.nixos-stuff;

  store = "/var/lib/nixos/boot";
  boot = "/boot";
  profiles = "${store}/nix/var/nix/profiles";
  profileName = "boot";
  tries = 3;
  instancesMax = 5;

  entry =
    pkgs.runCommand "entry.conf"
      {
        # we don't want to copy $toplevel to the $BOOT partition, so discard context
        options = builtins.unsafeDiscardStringContext (builtins.toString config.boot.kernelParams);

        kernel = "${config.boot.kernelPackages.kernel}/${config.boot.loader.kernelFile}";

        # NOTE: must make sure that the underlying derivation has no references.
        initrd = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";

        # When the title is not unique, falls back to title + version
        # if that is not unique,  title + version + machine-id
        # if that is not unique,  title + version + machine-id + filename

        # This means we do not need to dynamically generate entries titles at all.
        # systemd-boot will take care of it.
      }
      ''
        mkdir -p $out
        cat <<EOF > $out/entry.conf
        title NixOS
        kernel $kernel
        initrd $initrd
        options $options
        EOF
      '';

  installHook = pkgs.writeShellApplication {
    name = "install-bootloader";
    runtimeInputs = [
      pkgs.jq
      config.systemd.package
    ];
    runtimeEnv = {
      STORE = store;
      BOOT = boot;
      ENTRY = entry;
      INSTANCES_MAX = instancesMax;
    };
    text = ''
      	${builtins.readFile ./boot.sh}
    '';
  };
in
{

  options.boot.loader.nixos-stuff = {
    enable = lib.options.mkEnableOption "nixos-stuff bootloader";

  };

  config = lib.mkIf cfg.enable {

    systemd.sysupdate.enable = true;
    systemd.sysupdate.transfers."bootloader" = {
      Source = {
        Type = "regular-file";
        Path = profiles;
        MatchPattern = "${profileName}-@v-link/entry.conf";
      };
      Target = {
        Type = "regular-file";
        Path = "/entries";
        PathRelativeTo = "boot";
        MatchPattern = lib.map (v: "nixos-generation_${v}.conf") [
          "@v+@l-@d"
          "@v+@l"
          "@v"
        ];
        TriesLeft = tries;
        TriesDone = 0;
        InstancesMax = instancesMax;
      };
    };

    boot.loader.external = {
      enable = true;
      inherit installHook;
    };

  };
}
