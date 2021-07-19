final: prev: {
  # A minimal systemd with all the things I need for initrd
  systemdInitrd = prev.systemd.override {
    withMachined = false;
    withLogind = false;
    withDocumentation = false;
    withRemote = false;
    withImportd = false;

    # hmm?
    pam = null;
  };
}
