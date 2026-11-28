# Kernel lockdown keeps even root from modifying the running kernel
# ("integrity"), and from reading kernel memory ("confidentiality").
# Locked down, the kernel only loads signed modules, which
# ./kernel-certificates.nix provides for.
{ config, lib, ... }:
{
  imports = [ ./kernel-certificates.nix ];

  options.security.lockdown = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "integrity"
        "confidentiality"
      ]
    );
    default = null;
    description = "How far to lock the kernel down.";
  };

  config = lib.mkIf (config.security.lockdown != null) {
    boot.kernelParams = [ "lockdown=${config.security.lockdown}" ];
  };
}
