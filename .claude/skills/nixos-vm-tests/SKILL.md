---
description: Write, run and debug the NixOS VM tests in this repo (checks.nix, modules/**/*_test.nix, the Kubernetes/SPIRE/OpenBao/etcd tests). Use before adding a subtest or test, or when a test hangs or fails.
---

# NixOS VM tests in this repo

## Running

- `checks.nix` discovers every `modules/**/*_test.nix` and names the check after
  the file's `name` attribute. Defaults: `globalTimeout = 120`,
  `logLevel = "warning"`.
- **New files are invisible to `.#…`** in a jj workspace, because the git
  fetcher only sees files git tracks. Build untracked work with the path fetcher:
  `timeout 900 nix build -L --no-link "path:$PWD#checks.aarch64-linux.<name>" > /tmp/<name>.log 2>&1`
  Run that in the background and grep the log.
- Several tests can run at once (the build host has many cores). A test whose
  closure did not change finishes in seconds from cache; that's not a re-run.
- `path:` inputs are read lazily during evaluation, so editing files while a
  build is still evaluating can leak the edits into it. Don't edit until every
  build has started, and to know what a log tested, compare its drv path with
  `nix eval --raw "path:$PWD#checks.aarch64-linux.<name>.drvPath"`.
- Try protocol details against the binary on the host first (e.g. a local etcd
  or `bao server`): a minute instead of a VM run.
- Rough costs: `ops-etcd` ~3 min, `ops-openbao` ~5 min, `ops-spire` ~8 min,
  `kubernetes` ~9 min, `ops-control-plane` ~12 min. There is no way to rerun one
  subtest, so put new or flaky subtests early while iterating, then move them.

## Reading the output

A run prints 6–27k lines: every VM's serial console, interleaved. Don't scan it
for "error" or "failed", because every boot logs `module verification failed`.
Use:

```
grep -E 'subtest:|\(finished: |Traceback|AssertionError|Timed out|timed out' /tmp/<name>.log
grep '<machine> #' /tmp/<name>.log | grep -i '<unit or message>'
```

After a failure, `nix log <drv> | sed 's/\x1b\[[0-9;]*m//g'` gives the whole log
without ANSI codes. A `wait_*` timeout names the symptom, not the cause. The
cause usually sits much earlier: look for `start-limit-hit`,
`Dependency failed` and the units the waited unit `Requires=`.

## Writing tests

- Give every wait an explicit short timeout, and set `globalTimeout` on the
  test. Once `globalTimeout` fires the VMs are gone, so diagnostics in
  `except:` blocks fail with "Bad file descriptor". Keep `globalTimeout` well
  above the sum of the inner timeouts.
- Don't name Python variables `log` (a driver global); the type check fails.
- `succeed` raises on failure; `execute` and `systemctl` return
  `(status, output)`. `wait_until_succeeds` doesn't show the last attempt's
  output on timeout, so print it yourself when debugging.
- `execute()` on a VM that was shut down boots it again.
- Use `machine.shutdown(); machine.start()` for a clean reboot and
  `machine.crash()` for power loss. `start()` returns immediately; stage a
  power-on order with `time.sleep`.
- Model a config change an operator deploys with a `specialisation` and
  `/run/booted-system/specialisation/<name>/bin/switch-to-configuration test`
  (back with `/run/booted-system/bin/switch-to-configuration test`). After a
  switch, `/run/current-system/specialisation/` is gone, and a reboot boots the
  base configuration. Units with `restartIfChanged = false` (openbao) aren't
  restarted by a switch, so restart them explicitly or the subtest passes
  vacuously.
- For JSON bodies, write a file and pass `--data @file` rather than nesting
  quotes through Nix, Python and the shell.
- After a reboot, `journalctl -u` also returns earlier boots; pass `-b` or
  `--since @<epoch>` to assert on what happened since a point in the test.
- Start limits count every start, manual ones too: `systemctl reset-failed`
  before starting a unit that hit `start-limit-hit`.
- Assert on outcomes rather than on one log line from a racing component: a
  server log line that only appears when a client is slow makes a flaky test.
- Check that a negative assertion can fail: `fail("crictl images -q
  localhost/pause")` passed for months because that command never matches.

## SPIRE in tests (`modules/kubernetes/test-lib.nix`)

- Nodes attest like production: with the SPIRE `tpm` attestor, keys on disk.
  `modules/tpm2-ekcert-provisioning.nix` gives each VM's swtpm an EK cert from
  `tests/tpm-ca.*` whose TPM model is the host name. A node alias entry
  `t.nodeID host` (parent `spiffe://example.com/spire/server`, selector
  `tpm:model:<host>`) is the parent of every workload entry on the node.
- Agent IDs are `spiffe://example.com/spire/agent/tpm/<sha256 of the EK>`. The
  EK is new on every run, so look agents up with
  `spire-server agent list -output json` by their `tpm:model:<host>` selector.
- The swtpm state survives `shutdown()`/`crash()` and `start()`, so a node keeps
  its EK and agent ID across reboots, and wiping `/var/lib/spire/agent` just
  makes it attest again. `virtualisation.tpm.provisioning` runs on every VM
  start, so it must be idempotent; otherwise QEMU exits before the monitor
  connects.
- `crash()` drops data not yet written to disk. That's realistic, but results
  then depend on writeback timing; run `sync` first unless the lost writes are
  the point of the subtest.
- The test driver's shell is `systemd:id:backdoor.service`; register entries for
  it to give the driver an identity. Get its SVID with
  `spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write <dir>`.

## Conventions for the ops-* tests

Each `ops-*_test.nix` exercises one runbook in `modules/kubernetes/runbooks/`,
one subtest per procedure. A subtest that shows a weakness asserts the
behaviour we observe, with a comment saying why it's wrong, so fixing the
weakness flips the assertion.
