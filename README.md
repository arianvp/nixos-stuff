# nixos-stuff


## Deploying a computer

### On the machine
```
./deploy.sh
```

### Remotely from NixOS machine to NixOS machine
```
./deploy-remote.sh
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
