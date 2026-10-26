# `DBusActivatable=true` entries are never activated over D-Bus

Draft of an upstream report for [noctalia-dev/noctalia]. Not filed yet.

Kept here because `rice.nix` carries two workarounds for it: starting ghostty's
own systemd unit from `graphical-session.target`, and
`launch_apps_as_systemd_services`.

[noctalia-dev/noctalia]: https://github.com/noctalia-dev/noctalia

## Summary

Noctalia parses `DBusActivatable` but only uses D-Bus for an app that is
*already on the bus*. For an app that is not running it falls through to forking
`Exec=` from the desktop entry, so no activatable app is ever cold-started over
D-Bus.

Two consequences:

- Apps that rely on D-Bus activation do not launch at all from the launcher,
  while focusing an already-running instance works. That is very likely the
  undiagnosed [#3679].
- Apps never get the systemd unit their D-Bus service file names, so they are
  forked as children of the shell and inherit `noctalia.service`'s cgroup.
  Anything that stops or restarts that unit then takes the session with it.

Version: 5.3.0 (tag `v5.3.0`). Compositor niri 26.04, NixOS, noctalia running as
a systemd user service.

## Root cause

`src/system/desktop_entry_launch.cpp:220`:

```c++
  // Prefer D-Bus only when the app is already on the bus (focus / hand off).
  bool tryDbusActivation(const desktop_entry_launch::LaunchOptions& options) {
    if (!options.dbusActivatable || options.dbusAppId.empty() || !options.customCommand.empty()) {
      return false;
    }
    try {
      ...
      bool hasOwner = false;
      dbus->callMethod("NameHasOwner")
          .onInterface("org.freedesktop.DBus")
          .withTimeout(kProbeTimeout)
          .withArguments(options.dbusAppId)
          .storeResultsTo(hasOwner);
      if (!hasOwner) {
        return false;                     // :241 -- cold start never reaches Activate
      }
      ...
        proxy->callMethod("Activate")...  // :252
```

`launchEntry()` calls it at `:355` and, on `false`, goes on to
`parseCustomCommand(entry.exec, ...)` + `prepareCommand(...)` at `:367`.
`launchAction()` does the same at `:389`.

The bail-out at `:241` is silent. The two `"falling back to Exec"` messages are
in the `catch` blocks at `:262` and `:267`, and both are `kLog.debug`, so a
cold start leaves nothing in the log at all.

Everything else on the path is correct and is *not* the problem:

- `DBusActivatable` is parsed — `src/system/desktop_entry.cpp:392`.
- `entry.id = filepath.stem()` (`desktop_entry.cpp:254`) and `launchEntry()`
  uses it as `dbusAppId`, which is the right well-known name: ghostty's entry is
  `com.mitchellh.ghostty.desktop` and its bus name is `com.mitchellh.ghostty`.

## This contradicts the spec

Desktop Entry Specification, `DBusActivatable`:

> A boolean value specifying if D-Bus activation is supported for this
> application. If this key is missing, the default value is `false`. If the
> value is `true` then implementations should ignore the `Exec` key and send a
> D-Bus message to launch the application. [...] Applications should still
> include `Exec=` lines in their desktop files for compatibility with
> implementations that do not understand the `DBusActivatable` key.

So `Exec=` is the compatibility fallback, not the primary path. Noctalia
inverts that.

## What GLib does

`GDesktopAppInfo` is what wofi, `gio launch`, `gapplication launch` and GTK
launchers go through. From glib 2.88.3, `gio/gdesktopappinfo.c`.

It records `app_id` only for an activatable entry, at `:2071`:

```c
  /* Can only be DBusActivatable if we know the filename, which means
   * that this won't work for the load-from-keyfile case.
   */
  if (bus_activatable && info->filename)
    {
      ...
          if (g_dbus_is_name (basename) && basename[0] != ':')
            info->app_id = g_strdup (basename);        /* :2084 */
```

and then branches on that alone — `:3419` (sync), `:3523` (async):

```c
  if (session_bus && info->app_id)
    g_desktop_app_info_launch_uris_with_dbus (...);
  else
    g_desktop_app_info_launch_uris_with_spawn (...);
```

```c
  g_dbus_connection_call (session_bus, info->app_id, object_path,
                          "org.freedesktop.Application",
                          uris ? "Open" : "Activate", ...);   /* :3343 */
```

There is no `NameHasOwner` probe. It calls `Activate` unconditionally and lets
the bus start the service. That is the whole point of `SystemdService=` in a
D-Bus service file.

## Reproduction

With ghostty (any `DBusActivatable=true` app whose D-Bus service file has
`SystemdService=`):

```
$ cat ~/.local/share/dbus-1/services/com.mitchellh.ghostty.service
[D-BUS Service]
Name=com.mitchellh.ghostty
SystemdService=app-com.mitchellh.ghostty.service
Exec=/nix/store/...-ghostty-1.3.1/bin/ghostty --gtk-single-instance=true --initial-window=false

$ grep -E 'DBusActivatable|^Exec' /etc/profiles/per-user/arian/share/applications/com.mitchellh.ghostty.desktop
Exec=ghostty --gtk-single-instance=true
DBusActivatable=true
```

The activation path is live:

```
$ gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.ListActivatableNames | tr ',' '\n' | grep ghostty
 'com.mitchellh.ghostty'

$ systemctl --user show app-com.mitchellh.ghostty.service -p LoadState -p CanStart
LoadState=loaded
CanStart=yes
```

With no ghostty running, launch it from the noctalia launcher. Expected: the
unit starts. Actual:

```
$ systemctl --user is-active app-com.mitchellh.ghostty.service
inactive

$ ps -eo pid,ppid,cmd | grep "ghostty --gtk"
  28735    1764 ghostty --gtk-single-instance=true

$ cat /proc/28735/cgroup
0::/user.slice/user-1000.slice/user@1000.service/app.slice/noctalia.service
```

The command line is the desktop entry's `Exec=`, not the D-Bus service file's
(which ends in `--initial-window=false`), so it was forked, not activated. The
process sits in `noctalia.service`'s cgroup.

## Why the cgroup part matters

`noctalia.service` has the systemd defaults, `KillMode=control-group` and
`KillSignal=15`, so stopping it SIGTERMs everything in that cgroup.

Observed on a `nixos-rebuild switch` across a nixpkgs bump. NixOS restarts user
units whose unit file changed; noctalia's embeds `LOCALE_ARCHIVE` and `TZDIR`,
so every bump qualifies:

```
12:08:20.659  stopping the following user units: ..., noctalia.service, ...
12:08:20.666  Stopping Noctalia Wayland desktop shell...
12:08:20.732  app-ghostty-surface-transient-2490.scope: Consumed ... 1.3G memory peak
12:08:20.733  run-p26804-i26805.service: Deactivated successfully      <- the nixos-rebuild
12:08:20.791  Stopped Noctalia Wayland desktop shell
              noctalia.service: Consumed 5min 42s CPU, 5.2G memory peak
```

The compositor survived — NixOS marks niri `restartIfChanged = false` — but
every app died, including the terminal running the rebuild. Chromium went too:
its browser process had moved itself into its own scope, but the zygote and GPU
process it had forked earlier were still in `noctalia.service`, so they were
killed under it. It could not relaunch a GPU process, exhausted its fallback
modes and aborted deliberately:

```
OnProcessLaunchFailed -> RecordProcessCrash -> FallBackToNextGpuModeDueToCrash
  -> IntentionallyCrashBrowserForUnusableGpuProcess  (SIGTRAP, coredump)
```

This is the same blast radius as [#4400] and [#4614], which were closed by
putting `ExitType=cgroup` and `OOMPolicy=continue` on the `systemd-run` units
(`src/core/process/process.cpp:681`, `:684`). Those properties only apply when
`launch_apps_as_systemd_services` is on, and it still defaults to `false`.
Honouring `DBusActivatable` would fix it for activatable apps regardless of that
option, since the app would land in its own unit.

## Suggested fix

In `tryDbusActivation`, when `NameHasOwner` returns false, do not give up — the
name may still be activatable. Either consult
`org.freedesktop.DBus.ListActivatableNames`, or drop the probe and call
`Activate` directly and let the existing `catch` fall back to `Exec=` when the
app genuinely is not activatable. The second is what GLib does and needs no
extra round trip.

Worth keeping the probe only for picking `Activate` vs `ActivateAction`
semantics if that matters elsewhere; it should not gate launching.

## Related

- [#3679] — "[BUG] Not able to open some apps from the launcher" (open). Telegram,
  `DBusActivatable=true`. Reporter: *"i am able to switch to the open telegram
  window [...] but i am not able to start it from scratch with the launcher.
  this works with wofi"*. Exactly this bug; never diagnosed.
- [#4400], [#4614] — closed. Same cgroup sharing, reported as OOM blast radius.
- [#2757] — merged. Added `launch_apps_as_systemd_services`.

[#3679]: https://github.com/noctalia-dev/noctalia/issues/3679
[#4400]: https://github.com/noctalia-dev/noctalia/issues/4400
[#4614]: https://github.com/noctalia-dev/noctalia/issues/4614
[#2757]: https://github.com/noctalia-dev/noctalia/pull/2757
