# etcd runbook

Three etcd members (`etcd1..3.example.com`) run `modules/kubernetes/etcd.nix`.
SPIRE issues their certificates (`modules/kubernetes/spire.nix`). Facts that
matter for every procedure:

- Data dir: `/var/lib/etcd` on each member. Unit: `etcd.service`, runs as root,
  `Restart=on-failure` every 5s with no limit.
- Config: `/etc/systemd/system/etcd.service` → `--config-file /nix/store/...-etcd.yaml`.
  Flags and `ETCD_*` variables are **ignored**. Change settings through
  `kubernetes.etcd.settings`, never by hand.
- `initial-cluster` is static and `initial-cluster-state` is unset (`new`).
  Both only matter when the data dir is empty.
- Peers must present DNS SAN `etcd-peer`. Clients must present DNS SAN
  `kube-apiserver` (the API servers) or `etcd-admin` (operators, backups,
  monitoring; `kubernetes.spire.etcdAdmins`). etcd auth is off, so **whoever
  holds either SVID has full read/write on all of etcd**. `etcd-admin` SVIDs
  are not Kubernetes admins: the API server sees their SPIFFE ID as a user in
  no group.
- Each member serves `/health` and `/metrics` on `http://127.0.0.1:2381`
  (`kubernetes.etcd.settings.listen-metrics-urls`) without a client
  certificate.
- etcd restarts by itself, after a random delay of up to
  `kubernetes.spire.restartMaxDelaySec` (600s), whenever SPIRE adds a CA to the
  trust bundle. Check `journalctl -u etcd-svid-bundle` before you assume a
  restart was a crash.

## 0. Get an operator identity

Declare yourself an etcd admin on a machine with a SPIRE agent, and deploy it
and then the SPIRE server (which registers the entry):

```nix
kubernetes.spire.etcdAdmins.<you> = [ "unix:uid:0" ];   # any workload selectors
```

`ops-etcd` does this for the test driver with
`selectors = [ "systemd:id:backdoor.service" ]`. Then, on that machine:

```sh
mkdir -p /root/op && spire-agent api fetch x509 -socketPath /run/spire/agent/public/api.sock -write /root/op
export ETCDCTL_CACERT=/root/op/bundle.0.pem ETCDCTL_CERT=/root/op/svid.0.pem ETCDCTL_KEY=/root/op/svid.0.key
export ETCDCTL_ENDPOINTS=https://etcd1.example.com:2379,https://etcd2.example.com:2379,https://etcd3.example.com:2379
```

The SVID carries DNS SAN `etcd-admin` and the SPIFFE ID
`spiffe://example.com/k8s/etcd-admin/<you>`, so it is distinct from the API
servers' and cannot act on the Kubernetes API as an admin. Do not borrow
`/run/kube-apiserver-svid/*` on a control plane. The fetched SVID expires
(default 1h); fetch again when you get TLS errors. Do not try the member's own
`/run/etcd-svid/*`: it only carries `etcd-peer` and is rejected as a client,
with a misleading `context deadline exceeded` rather than an authorization
error. The commands below assume the variables above are set.

For a quick look on a member itself, no identity is needed:

```sh
curl -s http://127.0.0.1:2381/health    # {"health":"true",...}
curl -s http://127.0.0.1:2381/metrics | grep -E '^etcd_server_(has_leader|is_leader)|^etcd_mvcc_db_total_size_in_bytes'
```

## 1. Health check

**When**: on any alert, before and after every other procedure.
**Preconditions**: operator identity (section 0).

```sh
etcdctl endpoint health --cluster -w table   # every member: true, a few ms
etcdctl endpoint status --cluster -w table   # one IS LEADER=true; RAFT INDEX within a few of each other; DB SIZE well under 2 GB
etcdctl member list -w table                 # 3 members, all "started", IS LEARNER=false
etcdctl alarm list                           # empty
```

**Verification**: all four as described. A member that is `unhealthy` with
`context deadline exceeded` while others are fine is down or partitioned; look
at `journalctl -u etcd -u etcd-svid -b` on it.
**Rollback**: read-only.
Tested by: `ops-etcd` subtests 'health check', 'etcd-admin is not a Kubernetes
identity' and 'health and metrics without a client certificate'.

## 2. Rolling restart / reboot

**When**: kernel or etcd upgrades, host maintenance.
**Preconditions**: section 1 is fully green. Never touch a second member before
the first one is healthy again: with 3 members, two down = no writes.

For each member, one at a time:

```sh
ssh etcdN.example.com systemctl restart etcd.service   # or: reboot
# wait until this succeeds (usually seconds):
etcdctl endpoint health --cluster
etcdctl endpoint status --cluster -w table   # RAFT INDEX of etcdN caught up
```

After a reboot the node first needs its SPIRE agent to come back (it reuses the
SVID in `/var/lib/spire/agent`, or attests again with its TPM), then
`etcd-svid.service`, then etcd.

**Verification**: section 1. A graceful stop transfers leadership first, so
clients see no failed writes.
**Abort**: if the member does not come back within a few minutes, stop.
Do not restart the next one. Debug with `journalctl -u spire-agent -u etcd-svid -u etcd -b`.

> The node's SPIRE identity is its TPM, not its disk: an agent that lost
> `/var/lib/spire/agent` attests again by itself, under the same agent ID
> (`spiffe://example.com/spire/agent/tpm/<sha256 of the EK>`). Do not evict
> it. If `spire-agent` still fails, look on the SPIRE server: `spire-server
> agent list` shows whether the agent is banned, and the node alias
> `spiffe://example.com/node/etcdN` must select the node's TPM. A replaced
> disk keeps the TPM, so nothing changes on the SPIRE server. A replaced
> machine has a new TPM, so a new EK and a new agent ID: update the
> `tpm:pub_hash` selector of its node alias on the SPIRE server first (the
> test selects by `tpm:model`, which its swtpms set to the host name).

Tested by: `ops-etcd` subtest 'rolling restart' (etcd1 and etcd3 restarted,
etcd2 rebooted, a writer running throughout).

## 3. Quorum loss and recovery

**When**: two or more members down. Symptoms: every write and every
linearizable read times out (`context deadline exceeded`), `endpoint health`
fails on the survivors, API servers return errors or hang.
**Preconditions**: none. This is the emergency.

1. Do not wipe anything. Do not `member remove` anything (impossible without quorum anyway).
2. Bring members back, one is enough for quorum:
   ```sh
   ssh etcdN.example.com 'systemctl start etcd.service; journalctl -u etcd -b -n 50'
   ```
   If etcd will not start because of `etcd-svid.service`, fix SPIRE first (section 2 warning).
3. `etcdctl endpoint health` against the members that are up. Once two answer, writes work.
4. Bring back the remaining member, then section 1.

While quorum is lost, `etcdctl get --consistency=s <key>` against a survivor
still answers from its local, possibly stale, copy. Use that for diagnosis only.

If two members' data are gone for good, this becomes section 5 (restore).
**Verification**: section 1; a test write `etcdctl put /ops/probe $(date +%s)`.
Tested by: `ops-etcd` subtest 'quorum loss and recovery'.

## 4. Replace a member that lost its disk

**When**: `/var/lib/etcd` on one member is gone or corrupt (disk replaced,
`panic`s about the WAL or db), the node was reinstalled, or the journal shows
`member <id> has already been bootstrapped` in a restart loop.
**Preconditions**: the other two members are healthy (section 1). You will
run on 2 voting members until step 6: losing another one in between loses quorum.

Starting the member with the shipped config on an empty disk does **not**
work: it refuses with `has already been bootstrapped` and systemd restarts it
every 5s forever. That loop is harmless but tells you nothing more.

1. Stop it and clear what is left:
   ```sh
   ssh etcdN.example.com 'systemctl stop etcd.service; rm -rf /var/lib/etcd'
   ```
2. Remove the old member (the ID is the first column):
   ```sh
   etcdctl member list
   etcdctl member remove <ID>
   ```
3. Add it back as a learner (a non-voting member, so quorum is unaffected while it catches up):
   ```sh
   etcdctl member add etcdN --learner --peer-urls https://etcdN.example.com:2380
   ```
4. Deploy etcdN with `kubernetes.etcd.settings.initial-cluster-state = "existing";`
   (`initial-cluster` stays the full three-member list) and start it:
   ```sh
   nixos-rebuild switch ...   # on etcdN only
   ssh etcdN.example.com systemctl start etcd.service
   ```
   With `initial-cluster-state = "new"` the new member would try to found a
   cluster of its own.
5. Promote it once it has caught up (retry until it succeeds; it fails while the learner is behind):
   ```sh
   etcdctl member promote $(etcdctl member list | grep ', etcdN,' | cut -d, -f1)
   ```
6. Section 1. Check data is there locally:
   `etcdctl --endpoints https://etcdN.example.com:2379 get --consistency=s <known key>`.
7. Optional: revert `initial-cluster-state`. It is ignored once the data dir exists.

If the whole node was reinstalled on a new disk, its SPIRE agent attests again
with the TPM by itself once it boots; no eviction is needed. If it is a new
machine, update its node alias first (section 2 note).
**Abort**: before step 5, `etcdctl member remove <learner ID>` returns you to a
healthy 2-member cluster. After step 5, treat it like any member.
Tested by: `ops-etcd` subtest 'replace a member that lost its disk' (etcd3 loses
`/var/lib/etcd` and `/var/lib/spire/agent` and reboots; its agent comes back
under the same agent ID with a new SVID, then steps 1 to 7).

## 5. Snapshot backup and full restore

### Backup

Nothing takes backups automatically. Take one before every risky procedure and
on a schedule:

```sh
etcdctl --endpoints https://etcd1.example.com:2379 snapshot save /root/etcd-$(date +%F-%H%M).db
etcdutl snapshot status /root/etcd-*.db -w table
```

`snapshot save` needs exactly one endpoint. The snapshot holds Secrets
encrypted with OpenBao transit keys: store it off-cluster, and remember it is
only useful while those transit key versions exist (below).

### Full restore (disaster recovery)

**When**: quorum is lost and cannot be recovered (two or more data dirs gone or
corrupt), or the whole cluster must go back in time. This is destructive and
loses every write after the snapshot.
**Preconditions**:
- A snapshot that passes `etcdutl snapshot status`.
- **Every kube-apiserver stopped** (`systemctl stop kube-apiserver` on all
  control planes). Otherwise they keep serving and writing from their watch
  caches, and controllers act on a world that is about to vanish.
- The OpenBao transit key versions that encrypted Secrets in the snapshot still
  exist (check `bao read transit/keys/<key>`: `min_decryption_version` must be
  at or below the versions in use when the snapshot was taken). Otherwise the
  restored Secrets are undecryptable garbage.

Steps:

1. Stop etcd everywhere: `systemctl stop etcd.service` on etcd1, etcd2, etcd3.
2. Copy the snapshot to every member, then on **each** member (set N):
   ```sh
   mv /var/lib/etcd /var/lib/etcd.broken-$(date +%s)   # or rm -rf
   etcdutl snapshot restore /root/etcd.db \
     --name etcdN \
     --initial-cluster etcd1=https://etcd1.example.com:2380,etcd2=https://etcd2.example.com:2380,etcd3=https://etcd3.example.com:2380 \
     --initial-advertise-peer-urls https://etcdN.example.com:2380 \
     --data-dir /var/lib/etcd \
     --bump-revision 1000000000 --mark-compacted
   ```
   `--name` and `--initial-advertise-peer-urls` must match the member's config.
   `--bump-revision`/`--mark-compacted` make revisions move forwards and
   invalidate old watches, so Kubernetes informers relist instead of
   silently missing changes or seeing `resourceVersion` go backwards.
3. Start all members without waiting for each (a member only reports ready once a quorum is up):
   ```sh
   systemctl start --no-block etcd.service   # on all three
   ```
4. Section 1. Check a key you know predates the snapshot.
5. Start the API servers. Expect every controller and kubelet to relist.
   Objects created after the snapshot are gone, but their side effects (pods,
   cloud resources, PVs) may still exist; review them. Node and lease objects
   recover on their own.

**Rollback**: stop etcd, move the `/var/lib/etcd.broken-*` dirs back, start.
Tested by: `ops-etcd` subtest 'snapshot backup and full restore'.

## 6. Compaction, defrag and space quota

**When**: `DB SIZE` in `endpoint status` approaches the quota (default 2 GiB),
`alarm list` shows `NOSPACE`, or writes fail with `etcdserver: mvcc: database
space exceeded`.

The API server compacts history every 5 minutes, but nothing defragments, so
the file never shrinks on its own.

### Defrag (routine)

One member at a time. Defrag blocks that member for its duration (seconds per GB):

```sh
for n in 1 2 3; do
  etcdctl --endpoints https://etcd$n.example.com:2379 defrag
  etcdctl endpoint health --cluster || break
done
etcdctl endpoint status --cluster -w table
```

### NOSPACE recovery

With `NOSPACE` the **whole cluster** refuses writes, even if only one member is
over quota. Reads, deletes, compaction and defrag still work. Every member
reports `unhealthy: ... Active Alarm(s): NOSPACE`, so gate on
`etcdctl endpoint status --cluster` instead of `endpoint health` until step 4.

1. Find what grew: `etcdctl get / --prefix --keys-only | cut -d/ -f2-3 | sort | uniq -c | sort -n | tail`.
   Delete the garbage, or raise `quota-backend-bytes` (max ~8 GiB) and roll it out (section 2).
2. Compact to the current revision:
   ```sh
   rev=$(etcdctl --endpoints https://etcd1.example.com:2379 endpoint status -w json | jq '.[0].Status.header.revision')
   etcdctl compaction $rev
   ```
3. Defrag every member, one at a time:
   ```sh
   for n in 1 2 3; do
     etcdctl --endpoints https://etcd$n.example.com:2379 defrag
     etcdctl endpoint status --cluster -w table || break
   done
   ```
4. Disarm. The alarm survives restarts, compaction and defrag until you do:
   ```sh
   etcdctl alarm disarm
   etcdctl alarm list   # empty
   etcdctl put /ops/probe ok
   ```

**Rollback**: none needed; these are safe. Do not defrag all members at once.
Tested by: `ops-etcd` subtest 'compaction, defrag and space quota'.

## 7. Restarts caused by SPIRE CA rotation

Every member restarts once per new SPIRE CA, at a random time within
`restartMaxDelaySec` of the bundle changing. Two members restarting at the same
time is a brief quorum loss (see section 3; it heals by itself). If the API
servers report etcd errors at the same time on all control planes, check
`journalctl -u etcd-svid-bundle -u etcd` on each member for restarts in the
same window before doing anything else. In the test, two members restarted at
once were back to healthy after about 8s, with a few failed writes. No action is
needed beyond section 1.

The same goes for any deploy that changes the etcd config (`restartTriggers`):
deploy etcd members one at a time, never in parallel.

Tested by: `ops-etcd` subtest 'two members restart at once'.
