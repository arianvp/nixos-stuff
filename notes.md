# Show the difference between system you have and system you want to install
```
diff <(nix-store --query -R /run/current-system) <(nix-store -qR  $(nix-instantiate '<nixpkgs/nixos>')) 
```

# What is gonna change when you reboot:
```
diff <(nix-store -qR /run/current-system) <(nix-store -qR  /run/booted-system)
```
