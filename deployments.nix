self: super: {
  deployments = {
    "old.arianvp.me" = super.nixos (import ./configs/arianvp.me.bak);
    "arianvp.me" = super.nixos (import ./configs/arianvp.me);
    "ryzen" =  super.nixos (import ./configs/ryzen);
    "t430s" = super.nixos (import ./configs/t430s);
    "t490s" = super.nixos (import ./configs/t490s);
  };
  digitalocean-image = (super.nixos (import ./modules/digitalocean/image.nix )).digitalOceanImage;
  arianvp-website = ./website;
}
