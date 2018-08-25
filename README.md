# nixos-stuff


## Deploying a computer

### On the machine
```
sudo nixos-rebuild switch -I "nixos-config=./computers/$computer/configuration.nix" 
```

### Remotely from NixOS machine to NixOS machine
```
computer=<computer>
computerHost=<computer host>
buildHost=<build host>
nixos-rebuild switch -I "nixos-config=./computers/$computer/configuration.nix" --target-host="root@$computerHost" --build-host="root@$buildHost"
```

## Remotely from a nix computer to NixOS machine
```
TODO
```
