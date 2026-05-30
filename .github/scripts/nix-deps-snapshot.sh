#!/usr/bin/env bash
# Emit a GitHub Dependency Submission API snapshot for a NixOS system closure.
# Usage: nix-deps-snapshot.sh <host> <result-symlink> > snapshot.json
#
# Walks every store path in the closure of <result-symlink>, splits each store
# path basename into (pname, version) at the first "-<digit>" boundary, and
# emits one manifest named <host> with a pkg:generic purl per path.
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <host> <result-symlink>" >&2
  exit 1
fi

host="$1"
result="$2"

: "${GITHUB_SHA:?GITHUB_SHA not set}"
: "${GITHUB_REF:?GITHUB_REF not set}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID not set}"
: "${GITHUB_SERVER_URL:?GITHUB_SERVER_URL not set}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY not set}"

# nix-store -qR streams one store path per line. Piping through a single jq
# invocation keeps the closure (potentially tens of thousands of paths) off the
# argv, and avoids the `nix path-info --json` deprecation/format flux.
nix-store --query --requisites "$result" \
| jq --raw-input --slurp \
  --arg sha "$GITHUB_SHA" \
  --arg ref "$GITHUB_REF" \
  --arg run_id "$GITHUB_RUN_ID" \
  --arg host "$host" \
  --arg detector_url "$GITHUB_SERVER_URL/$GITHUB_REPOSITORY" \
  --arg scanned "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '
    split("\n")
    | map(select(length > 0))
    | map(
        . as $storePath
        | ($storePath | sub("^/nix/store/"; "")) as $basename
        | ($basename | sub("^[^-]+-"; "")) as $name
        # Split at the FIRST "-<digit>" boundary, matching the nixpkgs parseDrvName rule.
        | (if ($name | test("^.+?-[0-9][^ ]*$"))
           then ($name | capture("^(?<pname>.+?)-(?<version>[0-9][^ ]*)$"))
           else {pname: $name, version: ""}
           end) as $pv
        | {
            key: $basename,
            value: {
              package_url: (
                if $pv.version == "" then
                  "pkg:generic/" + ($pv.pname | @uri)
                else
                  "pkg:generic/" + ($pv.pname | @uri) + "@" + ($pv.version | @uri)
                end
              ),
              relationship: "direct",
              scope: "runtime"
            }
          }
      )
    | from_entries
    | . as $resolved
    | {
        version: 0,
        sha: $sha,
        ref: $ref,
        job: {
          id: $run_id,
          correlator: ("nix-closure-" + $host)
        },
        detector: {
          name: "nix-closure-submission",
          url: $detector_url,
          version: "0.1.0"
        },
        scanned: $scanned,
        manifests: {
          ($host): {
            name: $host,
            file: { source_location: ("hosts/" + $host + "/configuration.nix") },
            resolved: $resolved
          }
        }
      }
  '
