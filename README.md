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
nix-build ./nixpkgs.nix -A digitalocean-image
```

2. Upload it to Digitalocean
3. Start a droplet
4. you can now deploy with `nix run -f . deployments.arianvp-me -c deploy switch root@<droplet ip>`


# Setting up user environment

Note: Can not be used in conjunction with manual usage of `nix-env --install` as
this will override the environment that this installs

```
$ ./setup-user-env.sh
```

# TODOS:
Instead of have a deploy.sh, have a deploy.nix that generates a deploy.sh
This means everything is nicely in one closure
