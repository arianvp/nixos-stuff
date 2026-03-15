# nixos-stuff

Arian's personal NixOS configuration, managed as a [Nix flake](https://nixos.wiki/wiki/Flakes).

## How does this work?

This repository is a Nix flake that defines NixOS system configurations, reusable
NixOS modules, custom package overlays, and NixOS integration tests for several
machines.

### Repository layout

| Path | Purpose |
|---|---|
| `flake.nix` | Entry point — declares all inputs (nixpkgs, home-manager, …) and all outputs |
| `configs/` | Per-machine NixOS configuration files |
| `modules/` | Reusable NixOS modules shared across machines |
| `overlays/` | Custom nixpkgs overlays (patched / additional packages) |
| `packages/` | Standalone package derivations |
| `tests/` | NixOS integration tests (run with `nix flake check`) |
| `infra/` | Infrastructure-as-code (DNS via dnscontrol, OpenTofu) |
| `keys/` | Public SSH keys used by the machines |

### Machines (`nixosConfigurations`)

Each subdirectory under `configs/` corresponds to one `nixosConfiguration` entry
in `flake.nix`:

| Name | Description |
|---|---|
| `framework` | Framework 13" laptop (11th-gen Intel), daily driver with GNOME, lanzaboote secure-boot |
| `utm` | NixOS VM running inside UTM on Apple Silicon |
| `altra` | ASRock Rack ALTRAD8UD-1L2T server (ARM) |
| `arianvp-me` | Public-facing server at arianvp.me |

### Deploying a machine

Use `deploy.sh` on the **target machine itself** to build and switch to the
current configuration:

```bash
# Auto-detects the hostname and uses the matching nixosConfiguration
sudo ./deploy.sh --flake .

# Explicitly name the configuration
sudo ./deploy.sh --flake .#framework
```

The script runs `nix build` to produce the system closure, registers it as the
active profile in `/nix/var/nix/profiles/system`, and calls
`switch-to-configuration switch`.

### Modules (`nixosModules`)

The modules in `modules/` are exposed as `nixosModules.*` in the flake and can be
imported by any NixOS configuration. Some notable ones:

| Module | What it does |
|---|---|
| `home-manager` | Wires home-manager + noctalia shell into NixOS |
| `monitoring` | Prometheus + Grafana + Alertmanager stack |
| `spire-server/agent` | SPIFFE/SPIRE workload identity |
| `dnssd` | Avahi-based DNS-SD |
| `direnv` | System-wide direnv integration |
| `diff` | Shows a system diff on every activation |
| `cachix` | Cachix binary cache configuration |

Test files live alongside the modules they test and are named `*_test.nix`. They
are auto-discovered and run as part of `nix flake check`.

### Overlays

The overlays in `overlays/` extend nixpkgs with patched or additional packages:

| Overlay | What it provides |
|---|---|
| `spire.nix` | Up-to-date SPIRE / SPIFFE packages |
| `neovim.nix` | Custom neovim build |
| `fonts.nix` | Extra fonts |
| `openssh-audit.nix` | openssh-audit tool |
| `gnome-ssh-askpass4.nix` | GNOME SSH askpass |

### Packages (`packages`)

Standalone derivations available for `x86_64-linux`, `aarch64-linux`, and
`aarch64-darwin`:

- `spire` — SPIRE server/agent
- `spire-controller-manager` — SPIRE controller manager for Kubernetes
- `spire-tpm-plugin` — SPIRE TPM attestation plugin

### Running checks / tests

```bash
# Run all checks (builds packages + runs NixOS tests)
nix flake check

# Run a specific test
nix build .#checks.x86_64-linux.spire-join-token
```

### Dev shell

A dev shell with infrastructure tooling is provided:

```bash
nix develop
# Provides: doctl, opentofu, dnscontrol
```

