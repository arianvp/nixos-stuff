# OpenBao runbook

OpenBao holds two transit keys the control plane can't live without:

- `transit/keys/<clusterName>` (default `kubernetes`, aes256-gcm96) encrypts
  every Kubernetes Secret in etcd (`modules/kubernetes/encryption.nix`, role
  `kubernetes-kms`).
- `transit/keys/<clusterName>-service-accounts` (ecdsa-p256) signs every
  service account token (`modules/kubernetes/kube-jwt-signer.nix`, role
  `kubernetes-jwt-signer`).

**Impact of an outage**: API servers that are running keep serving Secrets from
their cached DEKs, but an API server **can't (re)start** without reading the
signing key, no new service account tokens can be issued, and new Secrets can't
be written once the DEK cache needs OpenBao. Treat OpenBao down as a control
plane outage in slow motion. **Impact of losing or rolling back a key**: Secrets
encrypted with a lost key version are gone for good, and service account tokens
signed with a lost version stop verifying.

Setup (`modules/spire/openbao.nix`):

- Three nodes, raft storage in `/var/lib/openbao` (a symlink to
  `/var/lib/private/openbao`, `DynamicUser`), API on `:8200`, cluster port `:8201`.
- `openbao1` has `spire.openbao.bootstrap = true`: on **empty storage** it
  initializes a **new** cluster, unless openbao2 or openbao3 says it is
  initialized, in which case it joins them (section 5). The others
  `retry_join` it.
- Raft node IDs are `<host name>-<12 hex digits>`, e.g. `openbao1-3f2a9c1e04bd`.
  The digits come from an app-specific hash of `/etc/machine-id`
  (`openbao-node-id.service` writes `BAO_RAFT_NODE_ID` to
  `/run/openbao-node-id/env` on every start), so a node keeps its ID as long as
  its machine ID stays, and a reinstalled machine joins as a new member. Show a
  node's ID with `cat /run/openbao-node-id/env`.
- `spire.openbao.nodeID` pins the ID (`storage.raft.node_id`) instead. Nodes
  that joined before the ID was derived have a random ID, which OpenBao keeps
  in `/var/lib/openbao/node-id`: before deploying this module to such a
  cluster, set `nodeID` on every node to the contents of that file (or to the
  `node_id` that `raft/configuration` lists for its address). Otherwise the
  node comes up under a new ID and never rejoins (section 8).
- Static seal: the key comes from the `seal-key` systemd credential. Nodes
  unseal themselves. There are no unseal keys to type in.
- No root token: self-init revokes it. Self-init creates **no recovery keys**
  (`sys/seal-status` shows `"n": 0, "t": 0`), and `sys/generate-root` returns
  `405 unsupported operation` either way. The only way in is cert auth with an
  X509-SVID.
- `openbao-config.service` reapplies policies and cert auth roles (including
  the trust bundle) on boot, on config change, and when SPIRE adds a CA. It
  fails on any reply but a 2xx and then retries every 5s, so `active` means
  everything was applied. It doesn't delete policies or roles removed from
  the configuration.

## 0. Getting in: shell setup

Every procedure below assumes this shell. Run it on a node where your SPIRE
identity is registered as an OpenBao admin: `kubernetes.spire.admins.<you>`
gives `spiffe://<td>/k8s/admin/<you>`, and that ID must be in
`spire.openbao.certRoles.admin.allowedURISANs` with a policy that covers what
you need.

```sh
B=https://openbao1.example.com:8200        # any node that is up
svid=$(mktemp -d)
spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write "$svid" >/dev/null
CA=$svid/bundle.0.pem                      # or /run/trust-bundle-svid/bundle.pem
TOKEN=$(curl -sS --fail-with-body --cacert "$CA" --cert "$svid/svid.0.pem" --key "$svid/svid.0.key" \
  --data '{"name": "admin"}' "$B/v1/auth/cert/login" | jq -r .auth.client_token)
bao() { curl -sS --fail-with-body --max-time 10 --cacert "$CA" -H "X-Vault-Token: $TOKEN" "$@"; }
unauth() { curl -sS --fail-with-body --max-time 10 --cacert "$CA" "$@"; }
```

The token lives 1h. Log in again when you get `403 permission denied`. Logging
in is a raft write, so it **fails without quorum** (`500 local node not active
but active cluster node not found`). Keep a token from before you start a
risky procedure.

**Break-glass when SPIRE is down**: the agent keeps serving the SVIDs it already
holds until they expire (default 1h), and OpenBao keeps accepting them, so the
shell above still works. Once they expire there is **no** way to authenticate.
Before SPIRE goes down for long, or right now as preparation, mint recovery keys
with an admin token (tested: works without any existing share) and store them
offline:

```sh
bao --data '{"secret_shares": 5, "secret_threshold": 3}' "$B/v1/sys/rotate/recovery/init" | jq .data.keys_base64
```

Note: in OpenBao 2.7.1, `sys/generate-root` still answers `405` after recovery keys
exist, so recovery keys don't give you a root token through that endpoint. Treat
them as authorization for recovery-key-gated operations only. Holding the SVID
admin role is the real break-glass. Make sure it is registered on more than one
node.

Tested by: `ops-openbao` subtest 'Health check' (an admin logs in with the SVID
the agent holds while `spire-server` is stopped; the server comes back with
the same CA from disk and the agents carry on).

## 1. Health check

**When**: on every alert, and before and after every procedure below.

**Preconditions**: shell setup (section 0). `sys/seal-status` and `sys/leader`
need no token.

**Steps**

```sh
for n in openbao1 openbao2 openbao3; do
  echo "== $n"; unauth "https://$n.example.com:8200/v1/sys/seal-status" | jq -c '{sealed, initialized, cluster_id, type, n, t}'
  unauth "https://$n.example.com:8200/v1/sys/leader" | jq -c '{is_self, leader_address, raft_committed_index}'
done
bao "$B/v1/sys/storage/raft/configuration" | jq -c '.data.config.servers[] | {address, node_id, voter, leader}'
bao "$B/v1/sys/storage/raft/autopilot/state" | jq '{healthy, failure_tolerance, voters, servers: (.servers | map_values({address, status, healthy, last_contact}))}'
bao "$B/v1/sys/storage/raft/autopilot/configuration" | jq .data
```

**Healthy means**

- every node: `sealed: false`, and **the same `cluster_id`**. A different
  `cluster_id` is a split brain (section 5). Act immediately.
- `sys/leader` on every node names the same `leader_address`.
- raft configuration: exactly 3 servers, all `voter: true`, one per address.
- autopilot: `healthy: true`, `failure_tolerance: 1`, 3 `voters`.
- `autopilot/configuration` has `cleanup_dead_servers: true`, `min_quorum: 3`
  and `dead_server_last_contact_threshold` from
  `spire.openbao.autopilot.deadServerLastContactThreshold` (default 24h, which
  OpenBao shows in seconds). `openbao-config` sets them (section 4).

**Transit smoke test** (doesn't touch the Kubernetes key):

```sh
bao -X POST "$B/v1/transit/keys/ops-smoke" >/dev/null   # once
ct=$(bao --data "{\"plaintext\": \"$(echo -n ok | base64)\"}" "$B/v1/transit/encrypt/ops-smoke" | jq -r .data.ciphertext)
bao --data "{\"ciphertext\": \"$ct\"}" "$B/v1/transit/decrypt/ops-smoke" | jq -r .data.plaintext | base64 -d
```

**Rollback**: read-only.

Tested by: `ops-openbao` subtest 'Health check'.

## 2. Rolling restart / reboot

**When**: OpenBao upgrade, kernel update, node maintenance.

**Preconditions**: section 1 is fully healthy (`failure_tolerance: 1`). Never
start the next node before the previous one is back. After a reboot the SPIRE
agent reuses the SVID in `/var/lib/spire/agent`, or attests again with the
node's TPM if that is gone, under the same agent ID
(`spiffe://<td>/spire/agent/tpm/<sha256 of the EK>`, see `spire-server agent list`).
No eviction is needed. OpenBao starts once `openbao-svid` has an SVID.

**Steps** (one node at a time, standbys first, active node last)

1. Find the active node: `unauth $B/v1/sys/leader | jq -r .leader_address`.
2. On the node: `systemctl restart openbao.service`, or `systemctl reboot`.
   For an upgrade, `nixos-rebuild switch` alone does **not** restart OpenBao
   (`restartIfChanged = false`). The restart in this step is what applies it.
   Stopping the active node triggers a leader election, and transit pauses for a
   few seconds.
3. Wait for it:
   `until unauth https://<node>:8200/v1/sys/seal-status | jq -e '.sealed == false'; do sleep 2; done`
4. Wait for autopilot:
   `until bao $B/v1/sys/storage/raft/autopilot/state | jq -e '.data.healthy and (.data.voters|length)==3'; do sleep 2; done`
   (a restarted node becomes healthy after `server_stabilization_time`, 10s).
5. Run the transit smoke test against the restarted node, then do the next node.

**Verification**: section 1 is healthy, and the smoke test passes on every node.

**Abort**: if a node doesn't unseal within 2 minutes, stop. Two nodes still
hold quorum. Check `journalctl -u openbao -u openbao-svid -u spire-agent -b` on it.
"no identity issued" means SPIRE: check on the SPIRE server that the agent is
not banned (`spire-server agent list`) and that the node alias
`spiffe://<td>/node/<node>` selects the node's TPM.
Never restart another node while one is down.

Tested by: `ops-openbao` subtest 'Rolling restart' (openbao1 and openbao2
restarted, openbao3 rebooted for real, transit checked while each node is down).

## 3. Quorum loss and recovery

**When**: two of three nodes are down. Symptoms: writes and logins fail with
`500 local node not active but active cluster node not found`. `sys/leader`
shows no `leader_address`.

**What still works**: a surviving node enters *read-enabled standby* within
seconds. It then still serves `transit/encrypt` and `transit/decrypt` for
**tokens that already exist**, so API servers that already hold a token keep
working. New logins fail (tested: `500 ... active cluster node not found`), so a
KMS plugin or `kube-jwt-signer-openbao` that restarts, or whose 1h token
expires, is locked out. **An API server that restarts now can't come back**,
because it can't read the service account signing key. This is your clock: don't
restart API servers, and get quorum back within the tokens' lifetime.

**Steps**

1. Don't wipe anything, and don't run `remove-peer`. Raft needs 2 of the 3
   original voters back.
2. Bring back any one of the down nodes (`systemctl start openbao`, or boot the machine).
3. Wait until `sys/leader` shows a `leader_address` and transit works on the
   surviving node.
4. Bring back the third node. Wait for section 1 to be healthy.

**If two nodes are permanently lost** (disks gone): the survivor can't form
quorum on its own. Restore from a raft snapshot (section 6) onto a freshly
bootstrapped cluster. This procedure is **untested**, and see section 6 for
what a restore loses.

**Abort**: n/a. Everything here is restarting existing members.

Tested by: `ops-openbao` subtest 'Quorum loss and recovery'.

## 4. Replace a non-bootstrap member that lost its disk (openbao2/openbao3)

**When**: the `/var/lib/openbao` of openbao2 or openbao3 is lost or corrupt, or
the machine was rebuilt.

**Preconditions**: the other two nodes are healthy (section 1, 2 voters
reachable). A replaced disk keeps the TPM: the reinstalled node's SPIRE agent
attests again by itself, under the same agent ID, and needs no eviction. A
replaced machine has a new TPM, so a new EK and a new agent ID: first update
the `tpm:pub_hash` selector of its node alias `spiffe://<td>/node/<node>` on
the SPIRE server.

**Steps**

1. On the node: `systemctl stop openbao.service`
2. `rm -rf /var/lib/openbao/*` (if the disk was replaced, it is already empty)
3. `systemctl start openbao.service`. `retry_join` joins the cluster under
   the same node ID, as the machine ID didn't change, so the node takes the
   place of its old peer.
4. Wait for unseal and autopilot health (section 2, steps 3 and 4).

**Verification**: `raft/configuration` has exactly 3 servers, one per address,
and the `node_id` of this node is the one it had before. Autopilot is healthy.

**If the machine was reinstalled** (new root file system, so a new
`/etc/machine-id`): there is nothing to wipe or remove. Deploy it and let it
boot. It joins under a new node ID with the same host name prefix. As it joins
at the address of its old member, autopilot removes the old member while it
adds the new one, so no dead voter stays behind. Verify as above, except that
the `node_id` of this node changed. A node that kept its root file system
but must join as a new member can get a new ID the same way: stop OpenBao,
`rm /etc/machine-id`, wipe `/var/lib/openbao/*` and reboot. Don't do that to
openbao1 while the other two are down (section 5).

**If the node is replaced by a machine with a different host name**: add the
new node to `retryJoin` and `managers` of the others, deploy it, and retire the
old one. Once the new node is a voter, autopilot removes the old one after it
has been out of contact for `dead_server_last_contact_threshold` (24h by
default). It never removes a voter if that would leave fewer than `min_quorum`
(`spire.openbao.autopilot.minQuorum`, the number of nodes): a node that is
down but not replaced stays a voter, and the cluster runs with
`failure_tolerance: 0` until it is back. To shrink the cluster for good,
remove the node by hand:
`bao --data '{"server_id": "<node_id>"}' $B/v1/sys/storage/raft/remove-peer`.

**Abort**: stop `openbao.service` on the node. The cluster keeps running on two nodes.

Tested by: `ops-openbao` subtest 'Replace a member that lost its disk'
(openbao3 loses `/var/lib/openbao` and `/var/lib/spire/agent` and reboots; its
agent comes back under the same agent ID with a new SVID, and OpenBao rejoins
under the same node ID), 'Reinstall a member' (openbao2 also loses
`/etc/machine-id`, boots with a new one and joins under a new node ID, and
its old member is gone) and 'Replace a member with a new machine' (openbao4
replaces a retired openbao3 and autopilot removes openbao3; a dead openbao4
then stays a voter because of `min_quorum` until openbao3 comes back, after
which autopilot removes openbao4; with a 1m threshold).

## 5. Replace the bootstrap member that lost its disk (openbao1)

**When**: openbao1 (`bootstrap = true`) lost `/var/lib/openbao`.

Before OpenBao starts on a `bootstrap = true` node, an `ExecStartPre` asks each
`retryJoin` node for `GET /v1/sys/init`, checking its certificate against the
trust bundle. If one answers `initialized: true`, OpenBao starts without its
self-init configuration and joins the cluster through `retry_join` like any
other member (section 4): under the same node ID, or under a new one if the
machine was reinstalled. The
journal of the `ExecStartPre` says which way it went:
`journalctl -u openbao -b | grep -E 'is initialized, joining|initializing the cluster'`.

**Preconditions**: openbao2 or openbao3 is up and serves `sys/init`. Use
`B=https://openbao2...`.

**Steps**

1. On openbao1: `systemctl stop openbao.service`
2. `rm -rf /var/lib/openbao/*` (if the disk was replaced, it is already empty)
3. `systemctl start openbao.service`
4. Verify that `cluster_id` on openbao1 equals openbao2's, the raft configuration
   has 3 servers, autopilot is healthy, and the transit smoke test passes on
   openbao1.

**Remaining danger: openbao1 with empty storage while no other node answers**.
If neither openbao2 nor openbao3 answers `sys/init` when openbao1 starts (both
down, unreachable, or without a valid SVID), openbao1 can't tell a lost disk
from the first boot of the cluster. It **self-initializes a brand-new
single-node cluster**: a new `cluster_id`, a **new `kubernetes` transit key and
a new service account signing key**, served on `openbao.example.com`, which
clients round-robin to. KMS plugins that land on it fail to decrypt existing
Secrets and encrypt new ones with a key the real cluster doesn't have, and
signers sign tokens the other API servers reject. Never start a wiped openbao1
while the other two are down. The same applies to any node deployed with
`bootstrap = true` and empty storage, e.g. a rebuilt machine.

To recover from that split brain:

1. On openbao1, `systemctl stop openbao.service` **now**. Check with
   `unauth https://openbao1.example.com:8200/v1/sys/seal-status | jq .cluster_id`
   (while it runs) that it differs from openbao2's.
2. Any Secret written by an API server whose KMS plugin talked to the rogue
   openbao1 is encrypted with the rogue key. If there is any chance of that,
   snapshot the rogue cluster first (`GET sys/storage/raft/snapshot` against
   openbao1, with a token from openbao1).
3. Once openbao2 or openbao3 is back and healthy, do steps 2 to 4 above.

**Abort**: stop `openbao.service` on openbao1. The cluster keeps running on two
nodes.

Tested by: `ops-openbao` subtest 'Replace the bootstrap member that lost its disk'
(openbao1 is wiped and started with its unchanged configuration, rejoins the
cluster with the same `cluster_id` and decrypts what was encrypted before).

## 6. Raft snapshot backup and restore

**When**: backup, regularly (nothing in the module does it). Restore only after
total loss of quorum with lost disks, or to undo destructive operator error.

**Preconditions**: an admin token. For restore: a healthy (or freshly
bootstrapped) cluster that unseals with the **same seal key** as when the
snapshot was taken. **A snapshot is useless without the seal key**: back the
key up separately (it's the `seal-key` credential, not in the snapshot) and
together with its `sealKey.id`.

**Backup**

```sh
leader=$(unauth $B/v1/sys/leader | jq -r .leader_address)
bao "$leader/v1/sys/storage/raft/snapshot" -o openbao-$(date +%F-%H%M).snap
test -s openbao-*.snap
```

Store it off-cluster, encrypted. It holds the transit key material
(seal-wrapped).

**Restore** (into the same cluster)

```sh
bao "$leader/v1/sys/storage/raft/snapshot-force" --data-binary @openbao-<date>.snap
```

`snapshot-force` is needed when the cluster's raft state differs from the
snapshot's (e.g. after re-bootstrap). Log in again afterwards: tokens created
after the snapshot are gone, and so are the KMS plugins' tokens. They log in
again by themselves.

**What a restore loses**: everything written after the snapshot, including
**transit key versions** of both keys. Service account tokens signed with a
signing key version newer than the snapshot stop verifying (tested: the
`kubernetes-service-accounts` key's `latest_version` rolls back). Pods get new
tokens when the kubelet refreshes them (within the hour), but anything holding a
long-lived token must be reissued. If the transit key rotated after the snapshot
(`auto_rotate_period`, default 720h, or a manual rotate), every Secret written
with the newer version becomes **undecryptable**. Tested: ciphertext produced
after the snapshot fails to decrypt after the restore. Before restoring, check
the newest key version in use (`etcdctl get /registry/secrets/... | grep -a -o
'kubernetes:[0-9]*'` or `transit/keys/kubernetes` `latest_version`) against the
snapshot's age. Afterwards, `kubectl get secrets -A -o name | xargs -n50 kubectl
get >/dev/null` finds the losses.

**Verification**: section 1 is healthy. Old ciphertext decrypts. The
`kubernetes` key's `latest_version` is as expected.

**Rollback**: take a fresh snapshot *before* `snapshot-force`, then restore that
one to undo.

Tested by: `ops-openbao` subtest 'Raft snapshot backup and restore'.

## 7. Seal key rotation

**When**: the seal key may have leaked, or as scheduled hygiene. Anyone holding
the seal key **and** a copy of `/var/lib/openbao` or a raft snapshot can read
every key in OpenBao.

**Preconditions**: section 1 healthy. A new 32-byte key, encrypted for each
node with `systemd-creds encrypt` if the old one was. A **new, never used** key
ID. The old key stays available on every node until step 4 is done.

`spire.openbao.sealKey.previous` sets OpenBao's `previous_key` and
`previous_key_id` and loads the old key as the `seal-key-previous` credential.
This is what the test deploys:

```nix
# step 1 configuration, on every OpenBao node
spire.openbao.sealKey = {
  file = "/path/to/new-key";
  id = "2";
  previous = { file = "/path/to/old-key"; id = "1"; };
};   # encrypted = true on either if that key is encrypted
```

**Steps**

1. Deploy the step 1 configuration to **all** nodes (`nixos-rebuild switch`).
   It doesn't restart OpenBao (`restartIfChanged = false`): the output says
   `NOT restarting the following changed units: openbao.service`.
2. One node at a time, active node last: `systemctl restart openbao.service`,
   then wait for unseal and autopilot health (section 2, steps 3 and 4). Once it
   unseals with `previous_key`, OpenBao rewraps its root key with the new key.
3. Deploy the final configuration (just `sealKey = { file = new; id = "2"; }`,
   without `previous`) to all nodes, and restart them one at a time again.
   They must unseal. If one doesn't, its journal says `unknown key id for
   data` (go back to step 1's configuration on that node).
4. Only now destroy the old key, and update the seal-key backup that goes with
   your raft snapshots: **old snapshots need the old key**. Keep the old key as
   long as you keep snapshots taken before step 2.

**Verification**: section 1 is healthy after a restart of each node. On each node,
`systemctl cat openbao` shows a config file whose `seal.static` has
`current_key_id` set to the new ID and no `previous_key`, and `journalctl -u
openbao -b` shows `current_key_id: "<new id>"`.

**Rollback**: until step 3, deploy the old configuration and restart. After step
2 the stored root key is wrapped with the **new** key: a node that comes up with
only the old key (e.g. booted into an older NixOS generation) **stays sealed**
(tested: `failed to decrypt keys from storage: unknown key id for data: 2`).
Never roll a node back past step 1 without also reverting the seal config.

Tested by: `ops-openbao` subtest 'Seal key rotation' (rotation through
specialisations on all three nodes, unseal after restarts with only the new key,
and a node rolled back to the old key stays sealed).


## 8. Full cold start

**When**: after a power loss or a datacenter-wide reboot. Everything is down.

**Preconditions**: the SPIRE server is up. OpenBao needs its SVID before it
starts.

**Steps**

1. Boot all three nodes, in any order. Each one unseals by itself from its
   static seal key, even alone, but stays a standby until a second node is up.
2. Wait until `sys/leader` names a leader and autopilot is healthy (section 1).
   In the test this takes well under a minute once two nodes are up.
3. Wait until `openbao-config` is `active (exited)` on every node. A node that
   boots while the old active node is still down advertises that dead node and
   answers every request with an empty `307` redirect to it. `openbao-config`
   fails on those (`HTTP 307 from …` in its journal) and retries every 5s until
   there is a leader, so it shows `activating (auto-restart)` meanwhile.
4. Run the transit smoke test. Then check that API servers start
   (`kube-jwt-signer-openbao` and `kube-kms-openbao` can log in).

**Verification**: section 1 is healthy, and `systemctl is-active openbao-config`
says `active` on every node.

**Abort**: n/a. If a node doesn't unseal, check `journalctl -u openbao -b` for
seal key errors (wrong credential, `unknown key id`) and SVID errors.

**A node that unseals but never rejoins**: its journal says `storage.raft: not
part of stable configuration, aborting election`, and autopilot shows a voter at
its address with `last_index: 0`. The node came up under a different node ID
than the raft configuration lists for its address, while keeping its raft
data: its machine ID changed, or `spire.openbao.nodeID` changed, e.g. on a
node that joined with a random ID (`/var/lib/openbao/node-id`) and was
deployed without pinning it (Setup). Compare `cat /run/openbao-node-id/env`
with the `node_id` of its address. Set `nodeID` to the old ID and deploy, or
make it join as a new member: stop it, wipe `/var/lib/openbao/*`, start it
(section 4, or section 5 for openbao1).

Tested by: `ops-openbao` subtest 'Full cold start' (all three crashed less
than a minute after openbao1 rejoined, openbao1 started alone, checks the 307
behaviour and that openbao-config keeps failing without a leader, then the
rest start, openbao-config succeeds and transit works).

