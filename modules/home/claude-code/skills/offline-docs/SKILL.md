---
name: offline-docs
description: Search local documentation offline with man, apropos and whatis. Use instead of WebSearch/WebFetch when looking up CLI flags, syscalls, config file formats, or library APIs that are documented in installed man pages.
---

# Offline documentation lookup

Installed software ships its own documentation. Prefer it over the web: it is
instant, needs no network, and — crucially — it documents the *exact version*
that is installed on this machine, which web docs often do not.

Reach for this before `WebSearch`/`WebFetch` whenever the question is "what does
this flag do", "what's the format of this config file", "what does this syscall
return", or "does this tool have an option for X".

## The three tools

| Tool | Answers |
|---|---|
| `whatis NAME` | "What is this thing?" — one-line description, exact name match |
| `apropos KEYWORD` | "What tool does X?" — searches names + descriptions of all man pages |
| `man [SECTION] NAME` | The full page |

On Linux (man-db) `whatis foo` is exactly `apropos -e foo` — an exact-name
lookup rather than a substring search. macOS's BSD `whatis` is looser and
matches substrings, so `whatis mount` there also turns up `automount(8)`;
skim the output rather than assuming a single hit.

## Manual sections

Names collide across sections. Always disambiguate when it matters:

| Section | Contents |
|---|---|
| 1 | User commands (`man 1 printf`) |
| 2 | System calls (`man 2 open`) |
| 3 | Library functions (`man 3 printf`) |
| 4 | Devices / special files (`/dev/*`) |
| 5 | File formats & config files (`man 5 crontab`, `man 5 sshd_config`) |
| 6 | Games |
| 7 | Miscellany / overviews (`man 7 signal`, `man 7 unix`) |
| 8 | System administration commands (`man 8 mount`) |

`man -a NAME` shows every section in turn; `whatis NAME` lists which sections
exist so you can pick.

## Recipes

Discover a tool for a task:
```bash
apropos 'compress'
apropos -s 1 'json'          # restrict to user commands
apropos 'ssh.*key'           # BSD apropos (macOS) takes a regex by default;
apropos -r 'ssh.*key'        # man-db (Linux) needs -r for regex
```

Identify something quickly:
```bash
whatis mount                 # shows mount(2) and mount(8) — different things
```

Grep inside a page instead of paging through it — `col -b` strips the
backspace-overstrike formatting so `grep` matches cleanly:
```bash
man 5 sshd_config | col -b | grep -A5 -i 'PermitRootLogin'
man 1 rsync     | col -b | grep -n -- '--delete'
```

Full-text search across *all* installed pages (slow, but finds things
`apropos` cannot — `apropos` only searches names and one-line descriptions):
```bash
man -K 'io_uring_setup'
```

Locate the source file, e.g. to read it whole or check where it came from:
```bash
man -w 5 nix.conf
```

## Notes

- Always pipe `man` output through `cat`/`col -b`/`grep` in a non-interactive
  shell so it does not try to invoke a pager and hang. Setting `PAGER=cat` or
  `MANPAGER=cat` works too.
- `apropos`/`whatis` read a prebuilt index. If they report "nothing
  appropriate" for something you know exists, the index is stale or missing —
  fall back to `man -k` (same thing), `man -K` (full text), or just `man NAME`
  directly, which does not need the index.
- Nix installs man pages per-package. A tool available via `nix shell` or a
  devshell only has its pages on `MANPATH` inside that shell — run `man` in the
  same shell as the tool.
- Man pages are not the only offline docs: also try `info NAME` (GNU projects
  keep the real documentation there), `NAME --help`, and `nix-store -q
  --references` style poking around `$(dirname $(readlink -f $(which NAME)))/../share/doc`.
