# Only lets the kernel execute, map as code, or load as a module or firmware
# what comes from the initramfs or from the dm-verity protected store of
# ./verity-store.nix. A binary written anywhere else never runs, not even as
# root.
#
# The policy names the store's root hash, so it can't be part of the store.
# It travels in a second initrd instead, which the UKI carries next to the
# main one, so that whatever measures the boot files covers it.
# IPE only loads policies signed by a key the kernel trusts. Like the modules,
# it is signed with kmodigest: the certificate is derived from the policy
# itself, enrolled through ./kernel-certificates.nix, and no signing key exists.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "nixos";

  storeVerityLabel =
    config.image.repart.partitions.${config.image.repart.verityStore.partitionIds.store-verity}.repartConfig.Label;

  template = pkgs.writeText "ipe-policy" ''
    policy_name=${name} policy_version=0.0.0
    DEFAULT action=DENY

    # The initramfs is emptied and unreachable after switching root.
    op=EXECUTE boot_verified=TRUE action=ALLOW
    op=KMODULE boot_verified=TRUE action=ALLOW
    op=FIRMWARE boot_verified=TRUE action=ALLOW

    op=EXECUTE dmverity_roothash=sha256:@usrhash@ action=ALLOW
    op=KMODULE dmverity_roothash=sha256:@usrhash@ action=ALLOW
    op=FIRMWARE dmverity_roothash=sha256:@usrhash@ action=ALLOW
  '';

  # kmodigest appends a detached signature in the kernel module format; IPE
  # wants a PKCS#7 message that carries the policy.
  attachPolicy =
    pkgs.buildPackages.writers.writePython3Bin "attach-policy"
      { libraries = [ pkgs.buildPackages.python3Packages.asn1crypto ]; }
      ''
        import sys

        from asn1crypto import cms

        marker = b"~Module signature appended~\n"

        signed = open(sys.argv[1], "rb").read()
        assert signed.endswith(marker)
        trailer = len(signed) - len(marker) - 12
        length = int.from_bytes(signed[trailer + 8:trailer + 12], "big")
        policy = signed[:trailer - length]

        message = cms.ContentInfo.load(signed[trailer - length:trailer])
        message["content"]["encap_content_info"]["content"] = policy
        sys.stdout.buffer.write(message.dump(force=True))
      '';

  # kmodigest only signs files named like kernel modules.
  policy =
    pkgs.runCommand "${config.image.baseName}-ipe-policy"
      {
        nativeBuildInputs = with pkgs.buildPackages; [
          attachPolicy
          cpio
          jq
          kmodigest
        ];
      }
      ''
        usrhash=$(jq -r '.[] | select(.label == "${storeVerityLabel}") | .roothash' \
          ${config.system.build.intermediateImage}/repart-output.json)
        substitute ${template} ${name}.ko --subst-var usrhash

        kmodigest ${name}.ko
        mkdir -p $out initrd/etc/ipe
        attach-policy ${name}.ko > initrd/etc/ipe/policy.p7s
        mv ${name}.ko.cer $out/policy.cer

        find initrd -exec touch --no-dereference --date=@1 {} +
        (cd initrd && find . -print0 | sort --zero-terminated \
          | cpio --quiet --create --null --format=newc --reproducible --owner=+0:+0) \
          > $out/initrd
      '';

  writeToSecurityfs = path: {
    unitConfig.DefaultDependencies = false;
    requiredBy = [ "initrd.target" ];
    before = [ "initrd.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "file:/sys/kernel/security/ipe/${path}";
    };
  };
in
{
  imports = [
    ./kernel-certificates.nix
    ./verity-store.nix
  ];

  security.lsm = [ "ipe" ];

  system.build.ipePolicyInitrd = "${policy}/initrd";

  boot.uki.settings.UKI.Initrd = toString [
    "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}"
    config.system.build.ipePolicyInitrd
  ];

  boot.kernel.certificates = [ "${policy}/policy.cer" ];

  boot.initrd.systemd.storePaths = [ pkgs.coreutils ];
  boot.initrd.systemd.services = {
    ipe-policy-load = lib.recursiveUpdate (writeToSecurityfs "new_policy") {
      description = "Load the IPE policy";
      serviceConfig = {
        ExecStart = "${pkgs.coreutils}/bin/cat";
        StandardInput = "file:/etc/ipe/policy.p7s";
      };
    };
    ipe-policy-activate = lib.recursiveUpdate (writeToSecurityfs "policies/${name}/active") {
      description = "Activate the IPE policy";
      requires = [ "ipe-policy-load.service" ];
      after = [ "ipe-policy-load.service" ];
      serviceConfig.ExecStart = "${pkgs.coreutils}/bin/echo 1";
    };
  };

  # Whoever holds CAP_MAC_ADMIN can switch IPE to permissive. The policy is
  # active by the time the initrd is done; take the capability away from
  # every process after that.
  systemd.settings.Manager.CapabilityBoundingSet = "~CAP_MAC_ADMIN";
}
