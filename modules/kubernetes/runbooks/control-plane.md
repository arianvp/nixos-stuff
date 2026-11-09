# Control plane runbook

Procedures for the Kubernetes control plane of `modules/kubernetes`:
kube-apiserver, kube-jwt-signer-openbao, kube-kms-openbao,
kube-controller-manager, kube-scheduler and the kubelets, and how they behave
when etcd, OpenBao or SPIRE go away.

Every procedure is exercised by the NixOS test `ops-control-plane`
(`modules/kubernetes/ops-control-plane_test.nix`):

    nix build -L .#checks.aarch64-linux.ops-control-plane

Timings below come from that test: 4 VMs, `infra` (SPIRE server, a single etcd
member, a single OpenBao node), `control1`, `control2`, `worker1`. Real hardware
boots slower; scale accordingly.

Conventions: `$CP` is a control plane host, `$DOMAIN` the DNS domain, `$BAO` the
OpenBao URL (`kubernetes.kube-jwt-signer.openbao`), `$KEY` the signing key
(`kubernetes.kube-jwt-signer.key`, default `<clusterName>-service-accounts`).

> **Read first, 3am operator.** OpenBao is a hard dependency of the control
> plane. Every service account token is signed by OpenBao, every Secret is
> decrypted with it, and **an API server node that boots or restarts its signer
> while OpenBao is down does not start at all**. If OpenBao is down, do not
> reboot or redeploy control plane nodes. Fix OpenBao first.

## Dependency and startup order

Arrows mean "needs". `Requires=` is hard. If the needed unit fails to *start*,
the dependent fails with "Dependency failed" and is **never retried by itself**.

```
spire-server  (KeyManager must be disk: with memory, a restart makes a new CA the
   ^           agents do not trust, and every agent crashes)
   |  :8081, node attestation (tpm: an agent that lost its key or SVID attests
   |         again with the node's TPM, under the same agent ID)
spire-agent   Restart=on-failure, RestartSec=100ms, default start limit:
   ^          5 quick failures and systemd gives up on it
   | Wants=
<x>-svid.service (spiffe-helper)   Restart=always, no start limit,
   |   TimeoutStartSec=2min: if no SVID within 2 minutes of boot, the start job
   |   fails and every unit that Requires= it fails with "Dependency failed"
   |
   +--> etcd                         (Requires etcd-svid)
   +--> openbao                      (Requires openbao-svid) --> openbao-config
   +--> kube-kms-openbao             (Requires kube-kms-openbao-svid; Before= apiserver;
   |                                  starts without OpenBao)
   +--> kube-jwt-signer-openbao      (Requires kube-jwt-signer-openbao-svid;
   |       Type=notify, TimeoutStartSec=infinity: READY only once it has read
   |       transit/keys/$KEY from OpenBao, retried every 5s)
   |         ^ RequiredBy=, Before=
   +--> kube-apiserver               (Requires kube-apiserver-svid and the signer)
   |       --> etcd (TLS, kube-apiserver SVID)
   |       --> kube-kms-openbao socket --> OpenBao transit encrypt/decrypt
   |       --> signer socket            --> OpenBao transit sign, keys cached 30s
   +--> kube-controller-manager, kube-scheduler   (Requires their svid; After= apiserver)
   +--> kubelet, kube-proxy                       (Requires their svid)

worker: crio (after an unclean shutdown it WIPES its storage when it starts)
        <-- kubernetes-images.service (oneshot, After= and BindsTo= crio: loads
            the images, including the pause image, every time crio starts)
        <-- kubelet (Requires crio, Wants= and After= kubernetes-images)
```

Consequences:

* No OpenBao, no kube-apiserver on a node that (re)boots: the signer never
  becomes ready, so the API server's start job waits forever. `systemctl` shows
  `kube-jwt-signer-openbao.service` as `activating` and `kube-apiserver` as
  inactive, with a pending start job. Nothing fails, so no alert fires on
  "failed units".
* Restarting only `kube-apiserver` keeps the running signer. Restarting the
  signer restarts the API server (it `Requires=` the signer).
* If SPIRE is unreachable for more than 2 minutes after a node boots, its etcd,
  OpenBao, KMS plugin, signer, API server, controllers, kubelet and kube-proxy
  fail with "Dependency failed" and stay down. The fix is
  `systemctl reset-failed && systemctl start multi-user.target`.

## Health check

**When to use:** after every procedure below, when paged, and before maintenance.

**Preconditions:** a shell on any node with `kubernetes.spire.apiServer` set, as
a process matching `kubernetes.spire.admins` (e.g. `unix:uid:1000`). `KUBECONFIG`
points at the `spiffe` kubeconfig, whose exec plugin fetches your X509-SVID from
the local SPIRE agent on every call. No SPIRE agent means no admin access. There
is no break-glass kubeconfig.

**Steps:**

```sh
kubectl auth whoami                      # your admin name, group system:masters
for cp in control1 control2; do          # every API server, not the one DNS picks
  echo "== $cp"
  kubectl --server=https://$cp.$DOMAIN:6443 get --raw '/readyz?verbose' | grep -v '^\[+\]'
  kubectl --server=https://$cp.$DOMAIN:6443 get --raw /livez; echo
done
ssh $CP systemctl is-active kube-jwt-signer-openbao kube-kms-openbao kube-apiserver \
  kube-controller-manager kube-scheduler
ssh $CP systemctl list-jobs              # a lingering start job = something is waiting
ssh $CP systemctl list-units --failed
kubectl get nodes
kubectl -n kube-system get lease kube-scheduler kube-controller-manager
kubectl create token default --duration=10m > /dev/null && echo "token signing ok"
```

**Verification:** `readyz check passed` with `[+]etcd ok` and
`[+]kms-providers ok`. All units active, no jobs, no failed units, nodes Ready,
and a token can be minted.

| Symptom | Meaning | Go to |
|---|---|---|
| `[-]etcd failed` (livez fails too) | etcd unreachable | [etcd outage](#etcd-outage) |
| `[-]kms-providers failed` | KMS plugin cannot reach OpenBao | [OpenBao outage](#total-openbao-outage) |
| `[-]informer-sync failed` + kms failed | API server started during an OpenBao outage | [OpenBao outage](#total-openbao-outage) |
| `create token` fails with `transit/sign ... connection refused` | OpenBao down, signing impossible | [OpenBao outage](#total-openbao-outage) |
| connection refused on :6443, signer `activating` | signer waits for OpenBao | [OpenBao outage](#total-openbao-outage) |
| `Dependency failed for Kubernetes API server` in the journal | SPIRE was unreachable at boot for > 2 min | [Cold start](#full-cluster-cold-start), step 3 |
| pods stuck `ContainerCreating`, events mention `localhost/pause` | the images are not loaded: `kubernetes-images` failed | [Worker crashed](#worker-crashed-or-lost-power) |

**Rollback/abort:** read-only.

Tested by: `ops-control-plane` subtest 'Health check'.

## Rolling reboot of the control plane

**When to use:** kernel updates, hardware work, anything that needs a control
plane node down. One node at a time.

**Preconditions:** the health check passes on **all** control planes. **OpenBao
and etcd are healthy.** The node will not come back without OpenBao. You have a
shell on a node that stays up.

**Steps, per node `$CP`:**

```sh
# 1. Both API servers ready; never take down the last ready one
for cp in control1 control2; do kubectl --server=https://$cp.$DOMAIN:6443 get --raw /readyz; echo; done
# 2. OpenBao is unsealed and reachable from $CP
ssh $CP curl -sf --cacert /run/trust-bundle-svid/bundle.pem $BAO/v1/sys/health
# 3. Reboot
ssh $CP systemctl reboot
# 4. Wait for it
until kubectl --server=https://$CP.$DOMAIN:6443 get --raw /readyz 2>/dev/null; do sleep 5; done
```

**Verification:** health check on all API servers.
`kubectl --server=https://$CP.$DOMAIN:6443 get secret <any>` works, which proves
that the KMS plugin reaches OpenBao.

What to expect (measured): the node is ready 17 to 20s after power-on. While it
is down:

* A **new** client connection to `api.$DOMAIN` (every `kubectl` run, every
  short-lived client) that tries the dead address first waits **~15s** before
  it tries the next address. Go splits its dial timeout across the addresses.
  An address that is powered off is a blackhole, not a refusal. Every kubectl
  call took 15.3s while `control1` (listed first) was off; there was no delay
  while `control2` was off. Long-lived clients (kubelet, controllers) keep their
  connection to the surviving node. Pods use the `kubernetes` Service, which
  dropped the dead endpoint at once on a clean shutdown.
* While the rebooted API server starts, it accepts connections before it is
  ready. Clients that DNS sends to it can get errors (the probe saw 3 of ~12
  `readyz` calls fail) and do not fail over, because they got an HTTP answer.

**Rollback/abort:** if the node is not ready within 5 minutes, leave it down. The
cluster works with one API server. Investigate with
`journalctl -b -u spire-agent -u kube-apiserver-svid -u kube-jwt-signer-openbao -u kube-apiserver`
and `systemctl list-jobs`.

Tested by: `ops-control-plane` subtest 'Rolling reboot of the control plane'.

## Service account tokens and the signing key

All API servers sign with one ECDSA P-256 key in OpenBao transit
(`transit/keys/$KEY`). Each `kube-jwt-signer-openbao` signs every token with a
live `transit/sign` call, re-reads the public keys every 30s, and keeps them in
memory to verify tokens. A new key version signs only after it is 60s old
(`publishDelay`), and every version OpenBao still lists stays trusted.

**When to use:** suspected key compromise, scheduled manual rotation, tokens
rejected after OpenBao maintenance.

**Preconditions:** OpenBao healthy; an OpenBao token with `update` on
`transit/keys/$KEY/rotate` (the test uses the cert auth `admin` role).

**Steps (rotate):**

```sh
curl -sf --cacert /run/trust-bundle-svid/bundle.pem -H "X-Vault-Token: $VAULT_TOKEN" \
  -X POST $BAO/v1/transit/keys/$KEY/rotate
# New tokens use the new kid after ~60s:
kubectl create token default | cut -d. -f1 | base64 -d 2>/dev/null; echo
```

**Verification (measured: new kid after 60s):** a token minted before the
rotation is still accepted by every API server, and a new token has a different
`kid` and is accepted by every API server:

```sh
for cp in control1 control2; do
  kubectl auth whoami --kubeconfig=/dev/null --server=https://$cp.$DOMAIN:6443 \
    --certificate-authority=/run/trust-bundle-svid/bundle.pem --token=$OLD_TOKEN
done
```

**Compromise:** rotating does **not** invalidate tokens signed by older
versions. The signers trust every version that `transit/keys/$KEY` lists. To
revoke the old versions: rotate, wait 60s, raise `min_decryption_version` and
`min_encryption_version` (`POST transit/keys/$KEY/config`), trim with
`POST transit/keys/$KEY/trim` (`min_available_version`), and then restart every
pod so its projected token is minted again. Within 30s every API server rejects
tokens from the trimmed versions. This path is **not tested**. Rehearse it
before you need it.

**Rollback/abort:** none. Rotation is additive.

Tested by: `ops-control-plane` subtest 'Service account tokens and their signing key'.

## Total OpenBao outage

**When to use:** `[-]kms-providers failed` on every API server, `create token`
fails, OpenBao down, sealed or unreachable.

**What happens (measured, single OpenBao node stopped):**

| Function | During the outage |
|---|---|
| Reading existing Secrets (running API server) | works (cached data keys) |
| Writing Secrets (running API server) | works for **~2.5 min**, then `encryptedDEKSource ... expired` |
| Verifying service account tokens | works (public keys cached by the signer) |
| Minting tokens (`kubectl create token`, kubelet projected volumes) | **fails at once**. New pods hang in `ContainerCreating` with `FailedMount ... transit/sign ... connection refused` |
| `readyz` | fails (`kms-providers`) within ~10s. A load balancer health-checking readyz would drop **all** API servers |
| `kube-apiserver` restarted (signer kept running) | starts, never ready (`kms-providers`, `informer-sync`). Every Secret read returns `StorageError: corrupt object ... data from the storage is not transformable`. **The data is not corrupt.** Non-Secret resources work. It logs decrypt errors ~10 times per second |
| signer restarted, or node rebooted | signer stays `activating`, **no API server on that node** |
| Existing pods | keep running, and keep reaching the API server with their existing tokens |

Recovery is automatic once OpenBao is back and unsealed (static seal unseals
itself). In the test: OpenBao unsealed at once, a running API server was ready
6s later, a restarted one ~20s later, and the stuck signer and its API server
came up by themselves. New pods were Running ~70s later (kubelet volume-mount
backoff).

**Steps:**

```sh
ssh $OPENBAO systemctl status openbao openbao-svid openbao-config
curl -s --cacert /run/trust-bundle-svid/bundle.pem $BAO/v1/sys/seal-status
ssh $CP journalctl -u kube-kms-openbao -u kube-jwt-signer-openbao --since -10min
```

1. **Do not restart or reboot API servers, signers or KMS plugins.** Each
   restart turns a degraded API server into a dead one (signer) or a
   Secret-less one (apiserver).
2. Freeze deploys and anything that creates pods or Secrets. Pod creation
   already fails, and Secret writes fail after ~2.5 minutes.
3. Fix OpenBao. It needs its SVID (`openbao-svid.service`, which needs the
   SPIRE agent) to serve TLS.
4. Watch it recover. No restarts are needed.

**Verification:** health check; `kubectl --server=https://$CP.$DOMAIN:6443 get secret <any>`
on every API server; create a throwaway Secret; `kubectl create token default`;
check that pods stuck in `ContainerCreating` start.

**Rollback/abort:** n/a.

Tested by: `ops-control-plane` subtest 'Total OpenBao outage'.

## etcd outage

**When to use:** `[-]etcd failed`.

**What happens (measured, single member stopped):** both API servers turn
unready within ~9s, and `/livez` fails too (do not use it for a liveness probe
that restarts the API server). Every storage request fails. The leading
controller-manager and scheduler lose their lease, exit, and are restarted by
systemd (`NRestarts=1`). **Running pods keep running and serving.** When etcd
returns, the API servers are ready within ~30s, the node is Ready and the
controller-manager holds its lease again, all without intervention.

**Steps:**

```sh
ssh $ETCD systemctl status etcd etcd-svid
ssh $CP 'etcdctl --endpoints https://$ETCD.$DOMAIN:2379 --cacert /run/kube-apiserver-svid/bundle.pem \
  --cert /run/kube-apiserver-svid/svid.pem --key /run/kube-apiserver-svid/svid.key endpoint health'
```

etcd accepts only clients whose SVID carries the DNS name `kube-apiserver`, so
run `etcdctl` on a control plane with the API server's SVID, as above.

1. Restore etcd. If `etcd-svid` failed, see the note under
   [Dependency and startup order](#dependency-and-startup-order).
2. Do not restart API servers, controllers or kubelets.

**Verification:** health check; the `kube-controller-manager` lease `renewTime`
is recent.

**Rollback/abort:** n/a.

Tested by: `ops-control-plane` subtest 'etcd outage'.

## Worker maintenance

**When to use:** rebooting or servicing a worker.

**Preconditions:** capacity elsewhere for its pods, or acceptance that they go
Pending (with one worker they do). OpenBao healthy: rescheduled pods need new
tokens.

**Steps:**

```sh
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --timeout=5m
ssh $NODE systemctl reboot          # a clean shutdown: CRI-O keeps its images
kubectl wait --for=condition=Ready node/$NODE --timeout=5m
kubectl uncordon $NODE
```

**Verification:** `kubectl get pods -A -o wide --field-selector spec.nodeName=$NODE`
shows pods Running; health check.

**Rollback/abort:** `kubectl uncordon $NODE` puts it back at any point.

Tested by: `ops-control-plane` subtest 'Worker maintenance'.

### Worker crashed or lost power

After an **unclean** shutdown, CRI-O wipes `/var/lib/containers/storage` when it
starts. `kubernetes-images.service` loads the preloaded images (including the
pause image) again once CRI-O is ready, and the kubelet starts after it, so
pods come back by themselves. If pods fail with `FailedCreatePodSandBox ...
localhost/pause`, the load failed:

```sh
ssh $NODE systemctl status kubernetes-images.service
ssh $NODE crictl images | grep pause || ssh $NODE systemctl restart kubernetes-images.service
```

Tested by: `ops-control-plane` subtest 'Cold start in the worst order'.

## Full cluster cold start

**When to use:** power returns after a site-wide outage, and everything boots
in an unknown order.

**What happens (measured, workers and control planes first, infra 30s later):**
the cluster converges by itself. Both API servers become ready, the worker
becomes Ready, Secrets are readable and workloads run again, because the API
servers' signers keep retrying until OpenBao is up, SPIRE was back well within
the svid units' 2-minute window, and the worker loads its images again after
CRI-O wiped them (see [Worker crashed](#worker-crashed-or-lost-power)).

Order matters for two reasons:

* If SPIRE is unreachable for more than **2 minutes** after a node boots, that
  node's units fail with "Dependency failed" and stay down (step 3 below).
* If OpenBao is not up, no API server starts.

**Steps:**

1. Power on in this order if you can: SPIRE server, etcd, OpenBao, control
   planes, workers.
2. Check SPIRE, etcd and OpenBao:
   ```sh
   ssh $SPIRE spire-server healthcheck
   ssh $CP 'etcdctl ... endpoint health'     # as in etcd outage
   curl -s --cacert /run/trust-bundle-svid/bundle.pem $BAO/v1/sys/seal-status
   ```
3. On every node where `systemctl list-units --failed` shows svid units or
   their dependents:
   ```sh
   systemctl reset-failed && systemctl start --no-block spire-agent.service multi-user.target
   ```
4. Run the health check.

**Verification:** health check; nodes Ready; workloads Running; Secrets
readable through every API server; pods reach the API server.

**Rollback/abort:** isolate (power off) a node that stays unhealthy, and treat it
with the per-node procedures above.

Tested by: `ops-control-plane` subtest 'Cold start in the worst order'.

## Kubernetes upgrade or configuration rollout

*Not exercised by the test. This section is based on reading `deploy.sh` and
the modules.*

**How deploys restart things.** `deploy.sh` builds the local host's
configuration (by `hostnamectl hostname`, or the given flake attribute), sets
the system profile, and runs `switch-to-configuration switch` **on the host it
runs on**. switch-to-configuration restarts every unit whose unit file changed,
all at once, with no readiness gate:

* A version bump of `pkgs.kubernetes` restarts `kube-apiserver`,
  `kube-controller-manager` and `kube-scheduler` together on that node.
* A change to the signer's options or package restarts
  `kube-jwt-signer-openbao` and therefore `kube-apiserver`. **During an OpenBao
  outage this kills the node's API server** (see above).
* A change to `kubernetes.encryption` changes the encryption config and so
  restarts the API server, and maybe `kube-kms-openbao`.
* etcd has `restartTriggers` on its config file.

`deploy.sh` has no notion of other hosts, so nothing serializes deploys between
control planes. If you run it on all control planes at the same time (an ssh
loop, an auto-upgrade timer, CI), they all restart together and the cluster has
no API server for the restart (~17s here). Deploy control planes one at a time
and gate each on `/readyz` of that node.

**Order for a minor upgrade (e.g. 1.37 -> 1.38):**

1. Read the "Urgent upgrade notes". Check removed flags against
   `kubernetes.kube-apiserver.args` and the other `args`.
2. Check that OpenBao and etcd are healthy (health check).
3. etcd first, if its version changes, member by member, gating on
   `etcdctl endpoint health`.
4. API servers **one at a time**: deploy `$CP`, wait for its `/readyz`, run the
   health check, then do the next. API servers may differ by one minor version
   during the upgrade.
5. kube-controller-manager and kube-scheduler must not be newer than the oldest
   API server. Here they share the host and restart with its API server, so
   during step 4 a new controller may talk to an old API server on the other
   node for a few minutes. Strictly, that is outside the skew policy. To follow
   it, keep controller/scheduler packages pinned to the old version until all
   API servers are upgraded.
6. Kubelets and kube-proxy last, node by node. They may be up to three minor
   versions older than the API server, never newer. Drain first if the change
   is disruptive.

**Verification:** health check after each host; `kubectl version`;
`kubectl get nodes -o wide`.

**Rollback:** on the host,
`nix-env -p /nix/var/nix/profiles/system --rollback && /nix/var/nix/profiles/system/bin/switch-to-configuration switch`.
`deploy.sh` sets the profile **before** switching (`nix build --profile`), so a
failed switch still leaves the broken generation as the boot default. Roll
back explicitly. Rolling back across a minor version is only safe before any
new API server has written objects in new storage versions. Prefer rolling
forward.
