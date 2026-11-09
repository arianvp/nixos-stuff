# SPIRE runbook

SPIRE is the root of trust of the whole cluster. There is no Kubernetes PKI:
etcd, every API server, controller manager, scheduler, kubelet, kube-proxy,
OpenBao and every admin's `kubectl` authenticate with an X509-SVID from the SPIRE
agent on their node, and trust the SPIRE trust bundle. **If SPIRE stops issuing
SVIDs, the cluster stops when the SVIDs on disk expire.**

Facts that matter for every procedure:

- **Server** (`services.spire.server`, production: `hosts/altra/spire.nix`):
  unit `spire-server.service`, `DynamicUser=yes`, so its state lives in
  **`/var/lib/private/spire/server`** (`/var/lib/spire/server` is a symlink) and is
  owned by a transient UID. It holds:
  - `datastore.sqlite3` (+ `-wal`, `-shm`): agents, registration entries, CA
    journal. The database runs in **WAL mode**: the `-wal` file routinely holds
    more than the main file, so copying `datastore.sqlite3` alone is not a backup.
  - `keys.json`: the private keys of the X.509 CA and the JWT signing key
    (`KeyManager "disk"`). Losing it means a new trust domain CA.
  - Admin socket: `/run/spire/server/private/api.sock`. Every `spire-server`
    command below needs `-socketPath /run/spire/server/private/api.sock`.
- **Registration entries are static.** `spire-controller-manager.service`
  on the server host turns `/etc/spire/server/manifests/*.yaml` into entries. Those files are
  generated from `kubernetes.spire.entries` of **every node**, merged into
  `kubernetes.spire.server.entries` of the server host. The controller manager
  recreates entries that are missing, so entries are never something you back up
  or restore by hand.
- **Agents** (`services.spire.agent`): unit `spire-agent.service`, user
  `spire-agent`, state in `/var/lib/spire/agent` (cached trust bundle, agent
  SVID, and with `KeyManager "disk"` the agent key). Workload API socket:
  `/run/spire/agent/public/api.sock`. On nodes with SVID consumers it has
  `Restart=on-failure` every 5 s and no start limit, so it keeps trying until
  it can attest.
- **Agents attest with their TPM** (`tpm` NodeAttestor from spire-tpm-plugin),
  in production and in the tests. The agent ID is
  `spiffe://<trust domain>/spire/agent/tpm/<sha256 of the EK public key>`: it
  stays the same for as long as the TPM does, but nobody knows it in advance.
  Find a node's agent ID by its TPM selectors (`tpm:pub_hash:…`, and in the
  tests `tpm:model:<host>`):
  ```sh
  spire-server agent list $S -output json \
    | jq -r '.agents[] | select(any(.selectors[]; .value == "model:<node>")) | "spiffe://\(.id.trust_domain)\(.id.path)"'
  ```
  Workload entries hang off a node alias (`spiffe://<trust domain>/node/<host>`
  in the tests), which the server gives to every agent whose TPM matches the
  alias's selectors.
- **Attestation can be repeated** (`Can re-attest : true` in `agent list`). An
  agent rotates its own SVID by attesting again (`Successfully reattested
  node`), attests again when the server denies it (`Agent needs to re-attest;
  will attempt to re-attest`), and attests afresh under the same ID when it
  lost its key or its SVID expired. **Eviction is not part of any normal
  recovery**; see section 6 for the exceptions.
- **Rebootstrap works with `trust_bundle_url`.** With `rebootstrap_mode =
  "auto"` (production), an agent that finds the server's CA missing from its
  bundle logs `Trust Bundle and Server don't agree, rebootstrapping`, exits,
  fetches the bundle again from `trust_bundle_url` after `rebootstrap_delay`
  (2 min in production), and attests again. SPIRE refuses to start an agent
  that combines rebootstrapping with `insecure_bootstrap` (the test-lib
  default), so such an agent has to be wiped by hand after the CA is lost.
- **SVID files**: one `spiffe-helper` unit per consumer, `<name>-svid.service`,
  writes `/run/<name>-svid/{svid.pem,svid.key,bundle.pem}`. The directories are
  kept when the helper stops (`RuntimeDirectoryPreserve`), so consumers go on
  using the last SVID until it expires. The helper restarts every 5 s without
  limit, and its unit stays `activating`, with no start timeout, until the
  files exist. Consumers `Requires=` it, so they wait for their SVID however
  long the agent takes, and start by themselves once it arrives.
- **Bundle watcher**: `<name>-svid-bundle.path` triggers
  `<name>-svid-bundle.service`, which restarts the consumer
  (`etcd`, `kube-apiserver`, `kube-controller-manager`, `kube-scheduler`,
  `kubelet`, `kube-proxy`, `kube-addons`) after a random delay in
  `[0, kubernetes.spire.restartMaxDelaySec]` (default 600 s) whenever a CA is
  **added** to the trust bundle. If a restart looks like a crash, check
  `journalctl -u '*-svid-bundle.service'` first.

TTLs (production uses SPIRE's defaults; `ops-spire` scales them down):

| | production | `ops-spire` |
|---|---|---|
| CA (`ca_ttl`) | 24 h; next CA prepared at 1/2, activated at 5/6 | 1 h |
| Workload SVIDs (`default_x509_svid_ttl`) | 1 h, renewed at 1/2 | 1 min |
| Agent SVID (`agent_ttl`, defaults to the above) | 1 h, renewed at 1/2 | 1 min |

## Blast radius / time budget without the SPIRE server

Measured in `ops-spire` subtest "SPIRE server outage longer than the SVID
lifetime" (TTL 1 min) and scaled to production (TTL 1 h). "t" counts from
the server stopping. A component fails at the worst case when its SVID was
renewed just before the outage began, and at the best case when it was due
for renewal.

| What | Breaks at (test) | Production | Why |
|---|---|---|---|
| New SVIDs, new entries, new nodes | t = 0 | t = 0 | nothing can be signed |
| SPIRE agent | 35–65 s | 30–60 min | its own SVID expires; it exits once, then keeps trying to attest until the server is back |
| Admin `kubectl` (exec plugin fetches from the agent) | 35–60 s | 30–60 min | agent gone |
| API server → etcd, kubelet → API server | 30–65 s | 30–60 min | client/serving SVIDs on disk expire |
| Every SVID file on disk | ≤ 60 s | ≤ 60 min | TTL |
| OpenBao listener | ≤ 60 s | ≤ 60 min | serves its SVID; clients reject it once expired |
| Service account token issuance (`kube-jwt-signer-openbao` → OpenBao transit) | 45–65 s | 30–60 min | OpenBao's serving SVID expires |
| Controller manager, scheduler | when the API server is gone | same | lose their leases and exit (and restart) |
| Running pods | keep running | keep running | but nothing can be scheduled, exec'd or updated; new pods get no token |

**Maximum tolerable SPIRE server downtime: half the agent SVID TTL, so
30 min in production.** Below that, nothing notices (subtest "SPIRE server
restart"). Above that the cluster is down until the server is back, but
then it recovers **by itself**: in `ops-spire` every agent attested again
0–11 s after the server started, and the whole cluster served again after
30–40 s, with no restarts except the controller manager and scheduler. Agents
have no start limit, so however often they exit during an outage they keep
trying. A node that boots during the outage waits with its consumers' start
jobs pending, and comes up by itself once the server is back (subtest "Nodes
boot while the SPIRE server is down").

## 0. Before you start

Run as root. On the server host:

```sh
export S="-socketPath /run/spire/server/private/api.sock"
```

On any node, `A=/run/spire/agent/public/api.sock`.

## 1. Health check

**When to use**: on any alert involving TLS, `x509`, `certificate`, or units
named `*-svid`, and before and after every procedure below.

**Preconditions**: none.

**Steps** (server host):

```sh
spire-server healthcheck $S                      # "Server is healthy."
spire-server localauthority x509 show $S         # Active authority + expiry; "Prepared" appears after ca_ttl/2
spire-server bundle show $S | openssl x509 -noout -subject -enddate
spire-server entry show $S -output json | jq '.entries | length'   # = number of files in /etc/spire/server/manifests
ls /etc/spire/server/manifests | wc -l
spire-server agent list $S                       # every node once, attested by tpm, "Can re-attest : true"
systemctl status spire-server spire-controller-manager
```

On every node:

```sh
spire-agent healthcheck -socketPath $A           # "Agent is healthy."
systemctl list-units '*-svid*' 'spire-agent*'    # all active; *-svid-bundle.service inactive is normal
for f in /run/*-svid/svid.pem; do echo "$f $(openssl x509 -in $f -noout -enddate)"; done
systemctl show -p Result,NRestarts spire-agent   # Result=success
```

**Verification**:
- every SVID's `notAfter` lies less than one SVID TTL in the future, and at
  least half of one. An SVID older than half its TTL means renewal is failing;
- `agent list` shows one agent per node, with `Expiration time` in the future.
  Two agents for one node mean its TPM (EK) changed; evict the old one
  (section 6);
- `Can re-attest : false` means the agent did not attest with its TPM, and
  none of the automatic recoveries below apply to it;
- `Result=start-limit-hit` on an agent means someone configured a start limit
  for it; go to section 6.

**Rollback/abort**: read-only.

Tested by: `ops-spire` subtest "Health check".

## 2. Restart or upgrade an agent

**When to use**: agent upgrade, config change, node reboot.

**Preconditions**:
- the server is healthy (section 1). If it isn't, an agent with its key on
  disk still starts and serves its unexpired SVIDs, but one that has to
  attest waits for the server.

**Steps**:

```sh
systemctl restart spire-agent
```

or deploy the new configuration with `nixos-rebuild switch`.

**Verification**: `spire-agent healthcheck -socketPath $A` within a few
seconds. With the key on disk (`KeyManager "disk"`, production and test-lib)
the journal shows `SVID loaded`, not `Starting node attestation`. An agent with
`KeyManager "memory"`, or one whose SVID expired, logs `Starting node
attestation` and `Node attestation was successful` under the same agent ID
instead. No consumer restarts: `systemctl show -p InvocationID etcd
kube-apiserver kubelet` is unchanged. The helpers reconnect by themselves.

**Rollback/abort**: if attestation fails, read `journalctl -u spire-agent`
and the server's journal. The usual causes are a server that can't be
reached, a TPM the agent can't open (`/dev/tpmrm0`, group `tss`), or an EK
certificate the server's `ca_path` doesn't trust. The agent retries every 5 s
until the cause is fixed.

Tested by: `ops-spire` subtests "Agent restart" (disk keys: nothing restarts,
nothing attests) and "Agent restart with keys in memory" (attests again by
itself under the same ID, nothing restarts).

## 3. Restart or upgrade the SPIRE server

**When to use**: SPIRE upgrade, server config change, host reboot.

**Preconditions**:
- **a fresh backup** (section 4);
- you can finish well within **half the agent SVID TTL** (30 min in
  production). If an upgrade could take longer, don't start it.

**Steps** (server host):

```sh
spire-server bundle show $S > /root/bundle-before.pem
systemctl restart spire-server     # or: nixos-rebuild switch
spire-server healthcheck $S
spire-server bundle show $S | diff - /root/bundle-before.pem && echo "CA unchanged"
```

**Verification**: the bundle is unchanged. Within one SVID TTL, every node's
`/run/*-svid/svid.pem` has a new `notAfter`. No consumer restarted. Agents
don't need any action.

**Rollback/abort**: roll back the generation (`nixos-rebuild switch --rollback`).
If the server does not start, read `journalctl -u spire-server`.
`permission denied` on `keys.json` means restored files have the wrong owner
(section 4). Keep an eye on the clock: past half the agent SVID TTL you are in
section 5.

Tested by: `ops-spire` subtest "SPIRE server restart".

## 4. Back up and restore the SPIRE server

**When to use**: backup: regularly, and before sections 3, 7 and 8. Restore:
the server host's disk is lost or corrupted.

**Preconditions**: `sqlite3` on the server host.

**Backup** (online, server keeps running):

```sh
D=/var/lib/private/spire/server
B=/root/spire-backup-$(date +%Y%m%dT%H%M%S)
mkdir -m 0700 $B
sqlite3 $D/datastore.sqlite3 ".backup $B/datastore.sqlite3"   # consistent, includes the WAL
cp $D/keys.json $B/
sqlite3 $B/datastore.sqlite3 'pragma integrity_check'        # "ok"
```

Never `cp` the live `datastore.sqlite3`: in `ops-spire` the WAL held over 1 MB
that the main file did not. Alternatively stop the server and copy the whole
directory. `keys.json` holds the CA private key: encrypt the backup and store
it like a root CA key.

**What a backup is worth: what matters is `keys.json`.** The datastore
records the serial number of each agent's current SVID, so a backup older than
the last agent SVID rotation (minutes) does not know the agents' SVIDs. After
such a restore the server denies every agent once (`Agent SVID is not active`
on the server, `PermissionDenied ... authorization denied for method ...` on the
agents), and the agents attest again with their TPM by themselves (`Agent
needs to re-attest; will attempt to re-attest`, `Successfully reattested
node`). Nothing restarts, and the CA survives, so nothing needs a new trust
bundle. Entries come back from the controller manager. Agents of nodes added
after the backup simply attest again as well.

**Restore**:

```sh
D=/var/lib/private/spire/server
systemctl stop spire-server
rm -rf $D/*
cp $B/datastore.sqlite3 $B/keys.json $D/
chown -R --reference=$D $D && chmod 0600 $D/*     # DynamicUser: the files must belong to the service's UID
systemctl start spire-server
spire-server healthcheck $S
spire-server bundle show $S | diff - /root/bundle-before.pem && echo "CA unchanged"
```

If `$D` itself is gone, start and stop `spire-server` once so that systemd
recreates it with the right owner, then restore.

**Verification**: the bundle is unchanged. Wait one agent SVID renewal (half
its TTL), then run section 1 on every node. After a stale backup, each agent
logs `authorization denied` once, followed by `Successfully reattested node`.
An agent that keeps logging `authorization denied` needs section 6.

**Rollback/abort**: keep the wiped state: `mv $D $D.broken` instead of
`rm -rf`.

Tested by: `ops-spire` subtests "SPIRE server backup and restore" (fresh
backup: nothing restarts, agents keep working) and "SPIRE server restore from a
backup older than an agent SVID" (the server denies the agents, they attest
again by themselves; no agent or consumer restarts).

## 5. Outage of the SPIRE server (it is down now)

**When to use**: the server is down or unreachable.

**Preconditions**: none. Watch the clock: you have **half the agent SVID TTL
from the start of the outage** (30 min in production) before the first
SVIDs expire, and one full TTL before the last one does. From then on the
cluster is down until the server is back.

**Steps**:
1. Find when it went down: `journalctl -u spire-server` on the server host,
   or on any node `journalctl -u spire-agent | grep -m1 'Could not reattest agent'`.
2. Bring it back (section 3; restore from backup with section 4 only if the
   state is lost).
3. If it is back **before** any agent's SVID expired, you're done: agents and
   helpers reconnect by themselves within seconds.
4. If not, each agent whose SVID expired has exited once
   (`current SVID has already expired and reattest agent failed`). The
   restarted agent keeps trying to attest (`Failed to retrieve attestation
   result`) and succeeds within seconds of the server's return
   (`Node attestation was successful`). Then the helpers and consumers pick
   up new SVIDs by themselves. Nodes that booted during the outage start
   their consumers by themselves too.

**Verification**: section 1 on every node; then `kubectl get --raw /readyz`,
`kubectl get nodes` (all Ready), and `etcdctl endpoint health`.

**Rollback/abort**: n/a.

Tested by: `ops-spire` subtest "SPIRE server outage longer than the SVID
lifetime". It asserts that every probe fails, that every agent restarted
and is still running 30 s after the last probe failed, and that once the server
is back everything recovers by itself. The only consumers that restart are the
controller manager and the scheduler, which lose their leases. Subtest "Nodes
boot while the SPIRE server is down" reboots control1 and worker1 during a
2.5-minute outage and asserts that their svid units are still `activating`,
that no unit failed with "Dependency failed", and that everything, including
`kube-addons`, comes up by itself once the server is back.

## 6. Recover an agent that does not recover by itself

**When to use**, while the server is healthy:
- an agent sits in `start-limit-hit`;
- an agent's cached bundle does not trust the server
  (`x509: certificate signed by unknown authority`) and it cannot rebootstrap
  (`insecure_bootstrap`, or no `trust_bundle_url`);
- an agent is banned (`agent ban`), or a node's TPM was replaced or reset, so
  it has a new EK and agent ID and the old one lingers in `agent list`.

**Preconditions**: the server is healthy.

**Steps**, per node. Control plane and etcd first. Start with the smallest
step that fits:

```sh
# start-limit-hit: let it try again
systemctl reset-failed spire-agent && systemctl start spire-agent

# a bundle that does not trust the server: wipe the agent's state
systemctl stop spire-agent
rm -rf /var/lib/spire/agent/*
systemctl reset-failed spire-agent
systemctl start spire-agent
```

Wiping `/var/lib/spire/agent` drops the cached bundle. The agent then fetches
the bundle again from `trust_bundle_url` (production) or trusts the first
server it reaches (`insecure_bootstrap`, the test-lib default). Only wipe
while you trust the network path to the server.

Evict only a banned agent, or the stale agent ID of a replaced TPM (find
it with the `jq` command in the facts above, or by its `pub_hash` selector):

```sh
spire-server agent evict $S -spiffeID spiffe://<trust domain>/spire/agent/tpm/<hash>
```

A replaced TPM also needs its new `tpm:pub_hash` in every entry that selects
the node by it (production's node entries do), deployed to the server host
(section 9).

**Verification**: within seconds, `journalctl -u spire-agent` shows `Node
attestation was successful` and `Creating X509-SVID` for every entry of the
node. The `spiffe-helper` units back off for up to ~15 s between retries, so
the SVID files refresh within about 30 s. Then run section 1. Consumers pick up
the new files without restarting, except when the CA changed (section 7).

**Rollback/abort**: an evicted agent only has to attest again; eviction
does not touch entries.

Tested by: `ops-spire` subtest "SPIRE server lost without backup" (the wipe,
for agents with `insecure_bootstrap`). Eviction and `start-limit-hit` are not
tested.

## 7. SPIRE server lost without a backup

**When to use**: `keys.json` is gone, with no backup. This means a new CA: a new
trust bundle for the whole cluster.

**Preconditions**: none. Expect a **full outage** of everything that
authenticates with SVIDs (all of Kubernetes, etcd, OpenBao), lasting until
every agent has the new bundle (step 3), plus up to `restartMaxDelaySec`.

**Steps**:
1. Start a fresh server: `systemctl stop spire-server; rm -rf /var/lib/private/spire/server/*; systemctl start spire-server`
   (or deploy the host anew).
2. Check that the controller manager registered every entry again:
   `spire-server entry show $S -output json | jq '.entries | length'` equals
   `ls /etc/spire/server/manifests | wc -l` (in `ops-spire` within seconds).
3. Agents still hold the old bundle and refuse the new server
   (`x509: certificate signed by unknown authority`). Agents with
   `trust_bundle_url` and `rebootstrap_mode = "auto"` (production) log
   `Trust Bundle and Server don't agree, rebootstrapping`, fetch the new
   bundle after `rebootstrap_delay` and attest again by themselves (in
   `ops-spire`, with a delay of 30 s, about 45 s after the new server
   started). Only the bundle endpoint's web PKI certificate vouches for the
   new CA.
4. Wipe every agent that bootstraps insecurely (`insecure_bootstrap`, the
   test-lib default) with section 6. There is nothing to evict: the new
   datastore is empty.
5. Every helper writes a bundle with a CA it has not seen. The bundle watcher
   restarts etcd, the API servers, controller managers, schedulers, kubelets,
   kube-proxies and kube-addons, each after a random delay of up to
   `restartMaxDelaySec` (600 s in production, so **up to 10 min**). To cut that
   short: `systemctl restart etcd kube-apiserver kube-controller-manager kube-scheduler`
   on control nodes, and `systemctl restart kubelet kube-proxy` on workers.
6. **OpenBao cert auth is now broken, and nothing repairs it.** Every cert
   auth role (`openbao-config`, `kubernetes-jwt-signer`, the KMS role, admins)
   trusts only the bundle that `openbao-config` wrote into it, i.e. the old CA.
   `openbao-config` itself has to log in with cert auth to write the new
   bundle, so it fails forever (`journalctl -u openbao-config`: `curl: (22)
   ... 400`, then `permission denied`). Service account tokens keep working
   only while `kube-jwt-signer-openbao` holds the OpenBao token it got before
   the loss. **Do not restart the signer or the API server until this is
   fixed**: the signer then has to log in, fails, stays `activating`, and
   `kube-apiserver` (which `Requires=` it) stays down. Fix it with a token
   that does not depend on cert auth (a root token generated with the
   OpenBao recovery/unseal procedure, see the OpenBao runbook):
   ```sh
   export BAO_ADDR=https://<openbao>:8200 BAO_CACERT=/run/trust-bundle-svid/bundle.pem BAO_TOKEN=<root token>
   for r in $(bao list -format=json auth/cert/certs | jq -r '.[]'); do
     bao read -format=json auth/cert/certs/$r | jq '.data' \
       | jq --rawfile c /run/trust-bundle-svid/bundle.pem '.certificate = $c' \
       | bao write auth/cert/certs/$r -
   done
   systemctl restart openbao-config     # on the OpenBao nodes; must now succeed
   bao token revoke -self
   ```
   A normal CA rotation does not need this: `openbao-config` reruns when the
   next CA is *added*, while its old-CA SVID still logs in.
7. Pods that mount the `kube-root-ca.crt` ConfigMap get the new CA from the
   controller manager. Workloads that cached the old CA have to be restarted.
   **Anything outside the cluster that pins the old bundle** (federated trust
   domains, CI systems) has to be updated by hand.

**Verification**: section 1 everywhere, `kubectl get --raw /readyz`,
`kubectl get nodes`, `etcdctl endpoint health --cluster`, and in OpenBao
`bao status` plus cert auth logins.

**Rollback/abort**: none. The old CA is gone.

Tested by: `ops-spire` subtest "SPIRE server lost without backup". It
asserts steps 1–5: entries return, control1's production-like agent
rebootstraps by itself, the `insecure_bootstrap` agents need wiping,
consumers restart by themselves, and the cluster serves again. It then
asserts that `openbao-config` keeps failing and that restarting the signer
takes the API server down for good. The OpenBao repair in step 6 is not
tested.

## 8. CA rotation

**When to use**: never by hand. SPIRE prepares the next CA at `ca_ttl/2`
(12 h), adds it to the bundle, and activates it at `5/6 ca_ttl` (20 h).

Each consumer restarts once, after a random delay of up to
`restartMaxDelaySec` (600 s), when the new CA reaches the bundle. Each etcd
member, API server and kubelet draws its own delay, with nothing to stop two
from coinciding. If an etcd member needs d seconds to restart and rejoin,
the chance that two of three members are down together is
1 − (1 − 2d/600)². That is about 3 % per rotation for d = 5 s, so a brief loss
of quorum about once a month with daily rotations. Check after every rotation:

```sh
journalctl -u '*-svid-bundle.service' --since -1h    # who restarted when
spire-server localauthority x509 show $S             # Active / Prepared / Old
```

**Verification**: section 1. All consumers' `ActiveEnterTimestamp` falls within
`restartMaxDelaySec` of the bundle change.

Tested by: `kubernetes` test, subtest "The cluster keeps working after SPIRE
rotates its CA", and `kubernetes-control-plane`, subtest "Everything keeps
working after SPIRE rotates its CA". Not repeated in `ops-spire`.

## 9. Add a node or change a registration entry

**When to use**: a new node, a new SVID-consuming service, a changed DNS SAN.

**Preconditions**: none.

**Steps**: entries come from each node's `kubernetes.spire.entries`, merged
into the server host's `kubernetes.spire.server.entries`. So:
1. Deploy the **SPIRE server host** first, with the new node in the merge.
   This regenerates `/etc/spire/server/manifests/*.yaml` and restarts
   `spire-controller-manager`.
2. Check: `spire-server entry show $S -spiffeID spiffe://.../k8s/node/<node>`.
3. Deploy the new node.

Deploying the node first makes its helpers hang with `no identity issued`
(retrying forever, the unit stays `activating`), and its consumers wait until
step 1 is done, then start by themselves. Removing a node from the merge
deletes its entries, so its SVIDs expire within one TTL.

**Verification**: section 1 on the new node.

Tested by: `ops-spire` subtest "Registration entries come from the
configuration of the SPIRE server" (only checks where entries come from).
