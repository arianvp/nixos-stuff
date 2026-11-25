# Lets systemd talk to the cloud's instance metadata service (IMDS) and import
# credentials from the instance's user data into /run/credstore:
#
#   {"systemd.credentials": [{"name": "…", "text": "…"}]}
#
# systemd-imds-generator pulls the units in where hwdb recognizes the cloud.
{
  systemd.additionalUpstreamSystemUnits = [
    "systemd-imdsd@.service"
    "systemd-imdsd.socket"
    "systemd-imds-early-network.service"
    "systemd-imds-import.service"
  ];

  users.users.systemd-imds = {
    isSystemUser = true;
    group = "systemd-imds";
  };
  users.groups.systemd-imds = { };

  # By default systemd only imports credentials in the initrd.
  boot.kernelParams = [ "systemd.imds.import=1" ];
}
