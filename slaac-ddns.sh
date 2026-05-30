#!/usr/bin/env bash
set -euo pipefail

IFACE="${1:?usage: $0 <iface> <fqdn> <zone>}"
HOST="${2:?}"
ZONE="${3:?}"
KEY="$CREDENTIALS_DIRECTORY/tsig"
TTL="${TTL:-300}"

# Wrap `update ...` lines from stdin in zone/send and run nsupdate.
nsupdate_tx() {
  { echo "zone $ZONE"; cat; echo "send"; } | nsupdate -k "$KEY"
}

# Read `ip -6 -o addr show` or `ip -o -6 monitor address` lines on stdin
# (their formats are identical apart from a leading "Deleted" on removals)
# and emit one line per stable global IPv6 address change:
#
#   ADD 2001:db8::1
#   DEL 2001:db8::1
#
# Example input lines:
#           2: eth0    inet6 2001:db8::1/64 scope global dynamic ...
#   Deleted 2: eth0    inet6 2001:db8::1/64 scope global ...
parse_events() {
  awk '
    /tentative|temporary/ { next }   # skip DAD-pending and RFC 4941 privacy
    !/scope global/       { next }   # skip link-local etc.
    {
      op = /^Deleted/ ? "DEL" : "ADD"
      for (i = 1; i <= NF; i++) if ($i == "inet6") {
        split($(i+1), a, "/")
        print op, a[1]
        next
      }
    }
  '
}

# Subscribe to netlink BEFORE snapshotting: events that occur during the
# snapshot accumulate in the kernel pipe buffer behind $mon and are drained
# after the reconcile. Post-reconcile each event is idempotent, so any
# overlap between snapshot and buffer is harmless.
exec {mon}< <(ip -o -6 monitor address dev "$IFACE" | parse_events)

# Initial reconcile: atomically wipe AAAA and republish the current set,
# sweeping any orphans from a prior unclean shutdown.
{
  echo "update delete $HOST AAAA"
  ip -6 -o addr show dev "$IFACE" scope global -temporary \
    | parse_events \
    | while read -r _ addr; do echo "update add $HOST $TTL AAAA $addr"; done
} | nsupdate_tx

# Drain buffered events, then live ones.
while read -r op addr <&"$mon"; do
  case "$op" in
    ADD) echo "update add $HOST $TTL AAAA $addr" ;;
    DEL) echo "update delete $HOST AAAA $addr" ;;
  esac | nsupdate_tx
done
