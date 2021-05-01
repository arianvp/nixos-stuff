prev: final: {
  # A minimal systemd with all the things I need for initrd
  systemdInitrd = prev.systemd.override {

  };
}
