---
name: bump-systemd
description: Bump systemd version in nixpkgs
---

# Instructions

When the user invokes this skill, help them bump the systemd version in nixpkgs. Follow these steps:

## 1. Get the target version

Ask the user what version they want to bump to, or fetch the latest from GitHub:
```bash
curl -s https://api.github.com/repos/systemd/systemd/releases/latest | jq -r '.tag_name'
```

## 2. Create a new change on staging

```bash
jj new staging -m "systemd: <old-version> -> <new-version>"
```

## 3. Review the release notes

Fetch and summarize the release notes for breaking changes, new dependencies, or removed features:
- URL: `https://github.com/systemd/systemd/releases/tag/v<version>`

Look for:
- Build dependencies that can be removed (vendored, no longer needed)
- New build dependencies that need to be added
- Removed features or options
- Changed meson options
- Patches that may need rebasing

## 4. Bump the version

Edit `pkgs/os-specific/linux/systemd/default.nix`:
- Update `version`
- Update `hash` (set to empty string `""` first, then run `nom-build -A systemd` to get the correct hash from the error)
- For **major version bumps**, also update `releaseTimestamp`:
  ```bash
  curl -s https://api.github.com/repos/systemd/systemd/releases/latest | jq '.created_at|strptime("%Y-%m-%dT%H:%M:%SZ")|mktime'
  ```

## 5. Push to open a PR

```bash
jj git push -c @
```

## 6. Test the build

```
nix-eval-jobs --meta --expr '(import ./. {}).systemd.passthru.tests' --workers 4 |  tee  eval.jsonl
cat eval.jsonl | jq  -r 'select(.meta.broken | not) | select(.system == "x86_64-linux")  | .drvPath  + "^*"' | nom build --stdin
```


## 7. Try on other release branches

Duplicate the change onto a branch where dependencies have landed. Try in this order:

1. **master** (preferred):
   ```bash
   jj duplicate @
   jj rebase -r <new-rev> -d master
   jj edit <new-rev>
   nom-build -A systemd
   ```

2. If master fails, try **nixos-<active-release>** (e.g. `nixos-25.11`):
   ```bash
   jj duplicate @
   jj rebase -r <new-rev> -d nixos-25.11
   jj edit <new-rev>
   nom-build -A systemd
   ```

3. If that fails, try **staging-next**:
   ```bash
   jj duplicate @
   jj rebase -r <new-rev> -d staging-next
   jj edit <new-rev>
   nom-build -A systemd
   ```

## 7. Clean up

After testing, abandon test duplicates and return to the original change:
```bash
jj abandon <test-rev>
jj edit <original-rev>
```
