# NixOS test framework friction (from this session)

Measured cost: **~3.5 h of agent wall-clock waiting on VM runs.** That's 31 runs
across 4 new tests: etcd 5 × 2 min, OpenBao 9 × 4.5 min, SPIRE 9 × 5–8 min,
control plane 8 × 12 min. About half of those runs existed only to get one more
piece of diagnostic information.

## 1. No way to rerun a subtest against live VMs (biggest cost)
A failure in the last subtest means a full rebuild, boot and replay of every
earlier subtest. Estimated savings had resume been possible: ~60 of 95 min on
ops-control-plane, ~40 of 55 min on ops-spire.
- *Upstream ideas:* VM snapshot/restore between subtests (QEMU `savevm`);
  `--start-at-subtest`; keeping the driver alive after a failure in
  non-interactive mode so a follow-up script can inspect the VMs (today only
  `driverInteractive` does this, and agents can't easily drive it).

## 2. Output is built for a human watching a terminal, not for analysis
- 6–27k lines per run. `logLevel = "warning"` still streams every VM's serial
  console, interleaved. The useful signal (subtests, timings, the failing
  command) is ~30 lines.
- No structured summary, so everyone writes their own
  `grep 'subtest:\|finished:'`. Log watchers got killed for volume 3+ times.
- Grepping for "failed"/"error" hits `module verification failed` on every boot,
  plus virtiofsd and eval-cache warnings. `nix log` output has ANSI codes.
- *Upstream ideas:* per-machine console logs written to a separate file instead
  of the main stream; a JSON/JUnit report of subtests with durations, status,
  and the failing command with its stdout/stderr; a log level that really means
  "driver events only".

## 3. Failures show the symptom, not the cause
- A `wait_for_unit` timeout said nothing about *why*. The root cause
  (`spire-agent` start-limit-hit → `Dependency failed`) was hundreds to
  thousands of lines earlier. This cost ~1 run for each of the four agents.
- `wait_until_succeeds` doesn't show the last attempt's output; `succeed`
  failures omit stderr. This cost ~3 runs.
- When `globalTimeout` fires, the VMs are killed before `except:` diagnostics
  run ("Bad file descriptor").
- *Upstream ideas:* on a `wait_*` timeout, automatically print the last
  attempt's output, `systemctl --failed`, and `systemctl status` plus the last
  journal lines of the waited unit and its `Requires=`; run a diagnostics hook
  *before* tearing VMs down on `globalTimeout`.

## 4. Driver API gaps and inconsistencies
- `succeed` raises; `execute` and `systemctl` return tuples.
- `execute()` on a shut-down VM silently boots it.
- `log` is a reserved global; shadowing it fails the type check (~1 run).
- Missing helpers that everyone hand-rolled: run a background process during a
  subtest; "stays failing for N s"; "time until failure"; "journal since t";
  time since power-on; staging a power-on order (`start()` returns immediately).
- A deprecation warning for bare-int timeouts fires only on `wait_until_fails`.

## 5. Config changes in a running test
- Specialisations plus `switch-to-configuration test` model operator deploys
  well (positive), but `/run/current-system/specialisation/` is gone after a
  switch, and a reboot boots the base config, which forces subtest ordering.
- A unit with `restartIfChanged = false` makes a switch-based subtest pass
  vacuously (seal rotation "passed" without rotating).

## 6. Static validation happens at runtime
SPIRE/OpenBao/etcd config errors only appear after a full VM boot.
`spire-server validate` on the build host takes seconds; build-time `validate`
checks in the modules would have saved ~2 runs.

## 7. Quoting
JSON inside shell inside a Python f-string inside a Nix string. Agents fell back
to base64-encoded body files.

## 8. TPM provisioning and reboots
`virtualisation.tpm.provisioning` runs on every VM start, but the swtpm state
survives `shutdown()`/`start()`, so provisioning that isn't idempotent (e.g.
`tpm2_nvdefine` of the EK cert index) makes the first reboot fail with "QEMU
exited before connecting to monitor socket". The real error is buried in the
QEMU start output. The option is `null or str`, so a test can't wrap it.
Upstream's `spire` test never reboots, so it doesn't notice.
- *Upstream ideas:* run provisioning only when the swtpm state is created, or
  document that it must be idempotent; make the option mergeable (`lines`).

## 9. `crash()` and writeback
`crash()` drops dirty pages, which is realistic but makes results depend on
timing. A real bug (OpenBao's raft `node-id` written without fsync) first looked
like a random flake. A documented `sync`-before-crash pattern, or a
`crash(sync=True)`, would make the intent explicit.

## 10. Repo-specific (fixed locally)
- New untracked files are invisible to the `git+file` flake in a jj workspace,
  so builds need the `path:` fetcher. Now documented in the skill.
- The tests used to attest with `http_challenge` and in-memory keys, so no test
  could reboot a node or restart the SPIRE server. They now attest with a TPM
  like production (`test-lib.nix`).
- Content-addressed reuse is nice: a rebase that doesn't change a test's closure
  "re-runs" in seconds. But `nix build` doesn't say "cached".

## Captured in the repo
`SKILL.md` next to this file: how to run, read
and debug the tests here, the driver gotchas above, SPIRE-in-tests pitfalls, and
the ops-* conventions.

## Fixing the findings: three agents in parallel
- `path:` inputs are read lazily, so edits made while a build evaluated leaked
  into it; the only reliable record of what was tested is the drv path.
- Three test-file changes from different agents passed on their own and failed
  together: one fix changed a log message that another test grepped for. Only a
  run of the whole suite on a merge of all stacks catches that.
- A subtest waited for a server log line that only appears when agents are slow
  to re-attest; it failed one run in three. Outcome-based assertions fixed it.
- The worktree isolation guard rejects commands containing `nix eval`, `$PWD`,
  chained `jj describe -m … &&` or `sed -f`, so agents wrote wrapper scripts.
- Creating several jj workspaces at once fails ("Concurrent checkout"); create
  them one at a time.
