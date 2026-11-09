# Control plane production readiness: operational weaknesses

Found while writing the runbooks in this directory and their tests, as of
2026-11-09 (PRs #193 → #205, with `kube-jwt-signer-openbao`). The
controller-manager identity PRs were not reviewed.

| Runbook | Test | Subtests | Run time |
|---|---|---|---|
| [spire.md](spire.md) | `ops-spire` | 9 | ~8 min |
| [etcd.md](etcd.md) | `ops-etcd` | 7 | ~3 min |
| [openbao.md](openbao.md) | `ops-openbao` | 8 | ~5 min |
| [control-plane.md](control-plane.md) | `ops-control-plane` | 7 (+ upgrade, runbook only) | ~12 min |

The existing `kubernetes` test also passes on the new stack (test script 205 s).
Subtests that hit a weakness **assert today's (bad) behaviour** and say why in a
comment. Each fix below should flip an assertion.

The tests attest nodes like production does: with their TPM, under a node alias
entry, with keys on disk (`test-lib.nix`).

---

## Critical

### C1. Wiping the OpenBao bootstrap node silently creates a second cluster
`initialize` is set whenever `bootstrap = true` (`modules/spire/openbao.nix:311`),
whether or not the data dir is empty. Re-installing or replacing openbao1
self-initializes a new single-node cluster instead of joining via `retry_join`.
The test shows the result:
- a new `cluster_id`;
- new transit keys for KMS **and** for service account signing;
- the node serves on the round-robin `openbao.<domain>`, so some API servers
  encrypt Secrets and sign tokens with keys the real cluster doesn't have;
- the real cluster keeps the dead voter, so `failure_tolerance` drops to 0.

*Test:* `ops-openbao` "Replace the bootstrap member that lost its disk".
*Fix:* only self-init when no `retry_join` peer is initialized (`ExecStartPre`
probe), or make `bootstrap` a one-shot that real configs never carry after day 1.

### C2. Partly fixed: an OpenBao outage still stops Secrets and new tokens
The token signer caches OpenBao's public keys on disk. A control plane node
rebooted during an OpenBao outage now gets its API server back: it verifies
existing tokens and serves everything but Secrets. Still broken while OpenBao is
down:
- token minting fails at once (every `Sign` is a live `transit/sign`); new pods
  hang in `FailedMount`;
- Secret writes stop after ~148 s (`encryptedDEKSource … expired`, the KMS v2
  DEK lifetime);
- an API server restarted during the outage can't read Secrets, reports them as
  `StorageError: corrupt object … not transformable`, and fails `readyz`
  (`kms-providers`, `informer-sync`) until OpenBao is back;
- `readyz` fails on every API server, so a readyz-based load balancer would
  drop all of them.

A signer with no cache (a node's first boot) still waits for OpenBao, and stays
`activating`, never `failed`, so alerting has to watch for stuck jobs.
*Test:* `ops-control-plane` "Total OpenBao outage", "Service account tokens and their signing key".
*Next:* an availability target for OpenBao, which is now as critical as etcd.

### C3. Fixed: pods start again after a worker crashes
`kubernetes-images` loads the preloaded images after CRI-O has wiped its
storage, and again whenever CRI-O restarts; the kubelet starts after it.
*Test:* `ops-control-plane` "Cold start in the worst order".

### C4. Losing the SPIRE server's keys breaks OpenBao cert auth for good, with no break-glass
Cert auth roles pin the trust bundle, and `openbao-config` can only refresh it
by logging in with cert auth. After a new SPIRE CA, every login fails with
400/403 indefinitely: KMS plugins, signers and admins. API servers come back
from the signer's cached keys, but can't read Secrets or issue tokens (C2).
There is no other way in:
- self-init revokes the root token and creates no recovery keys (`n: 0, t: 0`);
- `sys/generate-root` returns 405;
- no audit device is configured.

Conversely, any admin token can mint recovery keys with no shares
(`sys/rotate/recovery/init`).
*Tests:* `ops-spire` "SPIRE server lost without backup", `ops-openbao`
"Health check".
*Fix (workstream):* a break-glass path that doesn't depend on SPIRE (recovery
keys generated at init and stored offline, or an `upstream_authority` /
offline root so the trust anchor survives losing the server), plus an audit device.

### C5. Nothing is backed up, and the three stores must be restored together
- No timer exists for etcd snapshots, OpenBao raft snapshots or the SPIRE
  datastore and keys.
- The OpenBao transit key is the only KEK for every Secret, and the only key
  for every service account token. **Losing OpenBao means losing all Secrets.**
- Restores roll back key versions, as tested:
  - etcd restored without OpenBao keys of the same age leaves Secrets unreadable;
  - an OpenBao restore leaves newer ciphertext undecryptable and tokens signed
    with newer key versions invalid.
  - A stale SPIRE restore is harmless: the server rejects the agents' SVIDs and
    they attest again with their TPM.
- Backups need care:
  - the SPIRE sqlite runs in WAL mode, so `cp` is not a backup; use
    `sqlite3 .backup`;
  - the state is owned by a `DynamicUser` UID, so a restore needs a `chown`;
  - an OpenBao snapshot is useless without the separately held seal key.

*Tests:* the snapshot/restore subtests of all three.
*Fix (workstream):* one backup job that snapshots SPIRE, OpenBao and etcd in a
known order, with its own identities (see H6), encryption, off-host copies,
age alerts, and a tested restore runbook for the combination.

---

## High

### H1. SPIRE is a single point of failure: the cluster stops 30–60 min into an outage
There is one server, on sqlite. SVIDs default to 1 h and are renewed at half
that, so the cluster stops 30–60 min into a SPIRE outage: etcd peers,
API server ↔ etcd, kubelets and OpenBao fail, roughly in that order. It
recovers by itself once the server is back. Agents exit once when their SVID
expires, then keep re-attesting with their TPM, and the cluster serves again
30–40 s after the server returns. That was tested with a ~70 s outage; whether
agents keep retrying through a 30-minute one, without hitting their start limit
(H2), is not verified.
*Tests:* `ops-spire` "Outage longer than the SVID lifetime".
*Fix:* HA SPIRE servers on a shared datastore (or at least a warm standby with
restored keys), longer SVID TTLs, and alerts on SVID age.

### H2. Fixed: units wait and retry instead of giving up
- Fixed: `spire-agent.service` has no start limit on nodes with SVIDs, and the
  `*-svid.service` units wait for SPIRE as long as it takes, so their consumers
  (etcd, kube-apiserver, kube-addons, …) start once SPIRE is back instead of
  failing with "Dependency failed". *Test:* `ops-spire` "Nodes boot while the
  SPIRE server is down".
- A wiped etcd member crash-loops every 5 s forever (`member … has already been
  bootstrapped`); it fails safely, but nothing ever surfaces it.

*Remaining:* a unit that waits for SPIRE or OpenBao now stays `activating`
without a time limit, so alerting must watch for stuck jobs as well as failed
units.

### H3. `openbao-config.service` reports success while applying nothing
After a cold start, a lone standby answers with an empty `307` to the dead
leader. `curl --fail-with-body` doesn't fail on 3xx, and the script has no
`pipefail`, so the unit exits 0 and `RemainAfterExit` keeps it "active". If
SPIRE adds a CA in that window, cert auth never learns it, and every login fails
when the old CA expires. It also never deletes policies or roles removed from Nix.
*Test:* `ops-openbao` "Full cold start".
*Fix:* `set -o pipefail`, `jq -e`, check for a 2xx, `-L` or address the leader;
prune undeclared roles and policies.

### H4. Config deploys don't do what you'd expect
- `nixos-rebuild switch` never restarts OpenBao (`restartIfChanged = false` in
  nixpkgs). Seal key, `retry_join`, `bootstrap` and version changes wait for an
  unplanned restart.
- etcd's `restartTriggers` include bootstrap-only keys (`initial-cluster`), so
  editing the member list restarts every member.
- `deploy.sh` restarts changed units with no readiness gate or coordination
  between hosts, and sets the boot profile before switching, so a failed switch
  stays the boot default.

*Fix:* a rollout tool or ordering (one node at a time, gated on health); keep
bootstrap-only etcd keys out of the trigger; make OpenBao restarts explicit and
staged.

### H5. Restarts triggered by CA rotation are uncoordinated
Every etcd member, API server, kubelet and so on restarts at a uniform random
moment in [0, 600 s] when a CA is added. Measured restart windows give a brief
etcd quorum loss on **~2–8 % of rotations** (27 % for a multi-GB database): one
or more a month at the default daily CA cycle. The outage is longer when the
leader is one of the two (the leadership transfer times out).
*Fix:* deterministic per-member slots, or gate each restart on cluster health.
Better still, make etcd and the API server reload CA files so no restart is needed.

### H6. No operator, backup or monitoring identities for etcd
etcd accepts only the DNS SAN `kube-apiserver` (`modules/kubernetes/spire.nix:290`)
and auth is off. Operators, backups and Prometheus would all impersonate the API
server with full read/write, and audit can't tell them apart. There is no
`listen-metrics-urls`. Using a member's own SVID returns a misleading
`context deadline exceeded … unhealthy cluster` instead of an authorization error.
*Fix:* an `etcd-admin` allowed name, a metrics listener on loopback, and later
etcd RBAC.

### H7. Slow failover and no health checks on the endpoints
`api.<domain>` and `openbao.<domain>` are DNS round-robin. With the first
address down, every new kubectl connection takes 15.3 s. A starting API server
answers before it is ready, and clients don't fail over on an HTTP answer.
*Fix:* a VIP or load balancer with readiness checks (but see C2: readyz fails
everywhere during a KMS outage).


### H8. A power loss soon after an OpenBao node joins loses its raft identity
OpenBao writes `/var/lib/openbao/node-id` without fsync, and the module sets no
`storage.raft.node_id`. A crash shortly after a node (re)joins brings it back
under a new ID that the raft configuration doesn't know. It aborts every
election ("not part of stable configuration") and never rejoins, which leaves
the cluster at `failure_tolerance 0`.
*Test:* `ops-openbao` "Full cold start" (it syncs before crashing; without the
sync the subtest fails depending on writeback timing).
*Fix:* set `storage.raft.node_id` to the host name in `modules/spire/openbao.nix`.

---

## Medium
- **M1. Seal key rotation needs workarounds.** It works (OpenBao rewraps the root
  key), but the module has no `previous_key`, and the second credential needs
  `mkForce`. *Test:* `ops-openbao` "Seal key rotation".
- **M2. OpenBao quorum loss is worse than it looks.** A lone standby keeps
  serving transit for existing tokens, but logins fail (`active cluster node
  not found`). Any KMS plugin or signer that restarts, or whose 1 h token
  expires, is locked out.
- **M3. Dead raft peers are never removed.** Autopilot `cleanup_dead_servers`
  is off and `min_quorum` is 0.
- **M4. Nothing defragments etcd or watches its space.** One member over quota
  makes the whole cluster read-only. The alarm survives restart, compaction and
  defrag until someone runs `alarm disarm`, and `endpoint health` fails on every
  member meanwhile.
- **M5. Registration entries are compiled into the SPIRE server host.** Adding
  any node means deploying the SPIRE server host first.
- **M6. Revoking a compromised signing key is unplanned and untested.**
- **M7. The SPIRE CA key sits unencrypted on disk; etcd runs as root with no
  sandboxing.**
- **M8. Replacing a node's TPM, or the machine, needs a SPIRE server deploy, and
  eviction doesn't revoke.** A new TPM means a new EK and a new agent ID, and
  production's node aliases select by `tpm:pub_hash`, so the alias must be
  updated on the SPIRE server first. The old agent stays in `agent list` until
  evicted. Because TPM agents re-attest, `agent evict` doesn't keep a node out;
  revoking one takes `agent ban` or removing its alias, which is untested.

## Low
- OpenBao logs "unknown or unsupported field" warnings for the self-init request
  names at every start.
- SPIRE 1.15.4 requires `file_sync_interval` in `serving_cert_file`, despite the
  docs calling it optional.
- Agents that bootstrapped with `insecure_bootstrap` never accept a new SPIRE
  server and have to be wiped; production agents use `trust_bundle_url` and
  rebootstrap by themselves.
- The leading controller-manager and scheduler exit on lease loss (harmless);
  kubelet mount backoff slows recovery.

---

## Suggested workstreams, in order
1. **OpenBao bootstrap safety + `openbao-config` correctness** (C1, H3, H8). Small,
   high value.
2. **Done: node boot robustness** (C3, H2).
3. **Partly done: decouple the API server from OpenBao availability** (C2, M2):
   the signer starts from cached keys; an OpenBao availability target remains.
4. **Break-glass + trust anchor that survives losing SPIRE** (C4, H1): recovery
   keys offline, an upstream/offline root, HA SPIRE.
5. **Backups and coordinated DR** (C5, H6, M4) across all three stores.
6. **Rollout safety** (H4, H5): health-gated restarts and deploys.
7. **Endpoints and observability** (H7): VIP or LB, alerts on SVID age, etcd and
   raft health, KMS health, and units stuck `activating`.
