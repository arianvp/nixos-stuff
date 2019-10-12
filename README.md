# nixos-stuff

# Usage
```
nix run -f . deployments.t490s -c deploy [switch|boot|test] [target*]
```

# Example
```
nix run -f . deployments.arianvp-me -c deploy switch root@arianvp.me
```

# Deployments
These are defined in `overlays/deployments.nix`


# Deploying on digitalocean

1. Build the image
```
nix-build -A digitalocean-image
```

2. Upload it to Digitalocean
3. Start a droplet
4. you can now deploy with `nix run -f . deployments.arianvp-me -c deploy switch root@<droplet ip>`


# Setting up user environment
If you're not on NixOS

Note: Can not be used in conjunction with manual usage of `nix-env --install` as
this will override the environment that this installs

```
$ ./setup-user-env.sh
```

