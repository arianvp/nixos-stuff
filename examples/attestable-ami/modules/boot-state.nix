# Prints what the firmware measured and how the kernel is locked down to the
# console, for machines where the console is all an operator gets to see.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.log-boot-state;
  grep = args: toString ([ (lib.getExe pkgs.gnugrep) ] ++ args);
in
{
  options.services.log-boot-state = {
    pcrBank = lib.mkOption {
      type = lib.types.str;
      default = "sha256";
      example = "sha384";
      description = "The TPM PCR bank to print.";
    };
    pcrs = lib.mkOption {
      type = lib.types.listOf lib.types.ints.unsigned;
      default = [
        4
        7
        12
      ];
      description = "The PCRs to print.";
    };
  };

  config.systemd.services.log-boot-state = {
    description = "Print the boot measurements and the kernel's security state";
    wantedBy = [ "multi-user.target" ];
    after = [ "tpm2.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        (grep (
          [
            "--with-filename"
            "--no-messages"
            "."
          ]
          ++ map (pcr: "/sys/class/tpm/tpm0/pcr-${cfg.pcrBank}/${toString pcr}") cfg.pcrs
          ++ [
            "/sys/kernel/security/lockdown"
            "/sys/kernel/security/ipe/enforce"
          ]
        ))
        (grep [
          "--with-filename"
          "--no-messages"
          "--recursive"
          "--include=active"
          "."
          "/sys/kernel/security/ipe/policies"
        ])
      ];
      # Whatever the kernel doesn't support is missing.
      SuccessExitStatus = 2;
      StandardOutput = "journal+console";
    };
  };
}
