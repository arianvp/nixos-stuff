# Builds a kernel whose built-in keyring trusts exactly this system's kernel
# modules, plus `boot.kernel.certificates`, and boots the UKI into it.
#
# Nixpkgs signs each module with its own kmodigest certificate, derived from
# the module's contents, so enrolling the certificates of this system's modules
# admits those and nothing else, while keeping the kernel reproducible.
# Upstream hash-based module verification would replace the certificates with
# a single root hash:
# https://lore.kernel.org/all/20260505-module-hashes-v5-0-e174a5a49fce@weissschuh.net/
{
  config,
  lib,
  pkgs,
  ...
}:
let
  kernel =
    (config.boot.kernelPackages.rebuildImage { inherit (config.system) modulesTree; }).overrideAttrs
      (previousAttrs: {
        moduleCertificates = pkgs.runCommand "kernel-certificates" { } ''
          cat ${previousAttrs.moduleCertificates} ${toString config.boot.kernel.certificates} > $out
        '';
      });
in
{
  options.boot.kernel.certificates = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    default = [ ];
    description = ''
      DER encoded certificates to enroll in the kernel's built-in keyring, next
      to those of its modules.
    '';
  };

  config = {
    system.build.kernelWithCertificates = "${kernel}/${config.system.boot.loader.kernelFile}";
    boot.uki.settings.UKI.Linux = config.system.build.kernelWithCertificates;
  };
}
