self: super: {
  deployments = {
    "arianvp.me" = super.nixos (import ../computers/arianvp.me.bak);
    "new.arianvp.me" = super.nixos (import ../computers/arianvp.me);
    "ryzen" =  super.nixos (import ../computers/ryzen);
    "t430s" = super.nixos (import ../computers/t430s);
  };
  digitalocean-image = (super.nixos (import ../modules/digitalocean/image.nix )).digitalOceanImage;
  arianvp-website = ../website;
}
