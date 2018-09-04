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

# Setting up user environment

Note: Can not be used in conjunction with manual usage of `nix-env --install` as
this will override the environment that this installs

```
$ ./setup-user-env.sh
```
