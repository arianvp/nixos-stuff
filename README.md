# nixos-stuff

# Usage
```
$ ./deploy.sh <deployment> <target> [switch|boot|kexec]
```

# Deployments
These are defined in `overlays/deployments.nix`


# Deploying on digitalocean

1. Build the image
```
nix-build ./nixpkgs.nix -A digitalocean-image
```

2. Upload it to Digitalocean
3. Start a droplet
4. you can now deploy with `./deploy.sh <deployment> root@<droplet ip> switch`


# Setting up user environment

Note: Can not be used in conjunction with manual usage of `nix-env --install` as
this will override the environment that this installs

```
$ ./setup-user-env.sh
```
