self: super: {
  deployments = {
    "arianvp-me" = super.nixos (import ../computers/arianvp.me);
    "ryzen" =  super.nixos (import ../computers/ryzen);
    "t430s" = super.nixos (import ../computers/t430s);
  };
}
