# nixos-stuff


## Deploying a computer

### On the machine

```
./deploy.sh t430s localhost switch
```

### Remotely from NixOS machine to NixOS machine
```
./deploy.sh arianvp-me root@arianvp.me switch
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
