{

  # Partitions as in the initial image
  image.tpm2-device-key = ./srk.pub;
  image.partitions = [
    { type = "esp"; }
    {
      type = "root";
      label = "root";
      format = "ext4";
      minimize = "guess";
      encrypt = "tpm2";
    }
  ];

  partitions = [
    { type = "esp"; }
    {
      type = "root";
      label = "root";
      format = "ext4";
      size = "100%";
    }
  ];

  mounts = [
    {
      where = "/";
      what = "/dev/mapper/root";
    }
  ];

  luks = [
    {
      name = "root";
      device = "/dev/disk/by-partlabel/root";
    }
  ];

  automounts = [
    {
      where = "/efi";
      what = "/dev/disk/by-partlabel/esp";
    }
  ];

}
