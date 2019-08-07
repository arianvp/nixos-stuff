self: super: 
  # makes sure that all nix commands use our pinned nixpkgs
  let config = x: { imports = [ x ]; config.nix.nixPath = [ "nixpkgs=${./.}" ]; }; in {
  deployments = {
    "old.arianvp.me" = super.nixos (config ./configs/arianvp.me.bak);
    "arianvp.me" = super.nixos (config ./configs/arianvp.me);
    "ryzen" =  super.nixos (config ./configs/ryzen);
    "t430s" = super.nixos (config ./configs/t430s);
    "t490s" = super.nixos (config ./configs/t490s);
  };
  digitalocean-image = (super.nixos (config ./modules/digitalocean/image.nix )).digitalOceanImage;
  arianvp-website = ./website;
}
