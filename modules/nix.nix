{

    nix.settings.substituters = [
      "https://nixos.tvix.store?priority=39"
      "https://cache.nixos.org?priority=40"
    ];

    nix.settings.trusted-users = [
      "@wheel"
      "@nix-trusted-users"
    ];

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
      "fetch-closure"
    ];
}
