# Control plane runbooks

Maintenance procedures for the cluster that `modules/kubernetes` bootstraps
from SPIRE. Every procedure is exercised by a NixOS test, named in its
"Tested by" line; run one with
`nix build -L .#checks.aarch64-linux.<test>`.

| Runbook | Covers | Test |
|---|---|---|
| [spire.md](spire.md) | SPIRE server and agents: restarts, outages, backup and restore, losing the server, re-attestation | `ops-spire` |
| [etcd.md](etcd.md) | Rolling restarts, quorum loss, replacing a member, snapshot restore, defrag and space quota | `ops-etcd` |
| [openbao.md](openbao.md) | Rolling restarts, quorum loss, replacing members, raft snapshots, seal key rotation, cold start | `ops-openbao` |
| [control-plane.md](control-plane.md) | API servers, token signer, KMS plugin, outages of OpenBao and etcd, workers, cold start, upgrades | `ops-control-plane` |

Everything depends on SPIRE, and the API servers depend on etcd and OpenBao:

```
spire-server ─▶ spire-agent ─▶ <name>-svid.service ─┬─▶ etcd
                                                    ├─▶ openbao ─▶ openbao-config
                                                    ├─▶ kube-kms-openbao ──────┐
                                                    ├─▶ kube-jwt-signer-openbao ┤ (Requires)
                                                    └─▶ kube-apiserver ◀────────┘
                                                          ▲ etcd, OpenBao
kube-apiserver ◀─ controller-manager, scheduler, kubelet, kube-proxy, kubectl
```

Subtests that assert behaviour we consider wrong say so in a comment. When
fixing such a weakness, flip the assertion. [weaknesses.md](weaknesses.md)
ranks them and groups them into workstreams.
