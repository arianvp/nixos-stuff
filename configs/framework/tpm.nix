{ pkgs, ... }: {
  security.tpm2 = {
    enable = true;
    applyUdevRules = true;
    abrmd.enable = true;
  };

  environment.systemPackages = [ pkgs.tpm2-tools ];
}
