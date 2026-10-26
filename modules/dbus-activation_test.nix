{
  name = "dbus-activation";

  globalTimeout = 240;

  nodes.machine =
    { pkgs, ... }:
    let
      busName = "org.example.TestApp";

      # A minimal GApplication, so the well-known name is really taken and
      # org.freedesktop.Application.Activate is really handled.
      testApp =
        pkgs.runCommandCC "test-app"
          {
            nativeBuildInputs = [ pkgs.pkg-config ];
            buildInputs = [ pkgs.glib ];
          }
          ''
            cat > app.c <<'EOF'
            #include <gio/gio.h>
            static void on_activate(GApplication *app, gpointer data) { (void) app; (void) data; }
            int main(int argc, char **argv) {
              GApplication *app = g_application_new("${busName}", G_APPLICATION_DEFAULT_FLAGS);
              g_signal_connect(app, "activate", G_CALLBACK(on_activate), NULL);
              g_application_hold(app);
              return g_application_run(app, argc, argv);
            }
            EOF
            mkdir -p $out/bin $out/share/applications $out/share/dbus-1/services
            $CC app.c -o $out/bin/test-app $(pkg-config --cflags --libs gio-2.0)

            cat > $out/share/applications/${busName}.desktop <<EOF
            [Desktop Entry]
            Type=Application
            Name=TestApp
            Exec=$out/bin/test-app
            DBusActivatable=true
            EOF

            cat > $out/share/dbus-1/services/${busName}.service <<EOF
            [D-BUS Service]
            Name=${busName}
            SystemdService=app-${busName}.service
            Exec=$out/bin/test-app
            EOF
          '';
    in
    {
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        linger = true;
      };

      environment.systemPackages = [
        testApp
        pkgs.glib.bin
      ];
      environment.pathsToLink = [ "/share/dbus-1" ];

      # A lingering user has no login session, so the socket-activated bus
      # would start without XDG_DATA_DIRS and never find the service file.
      services.dbus.implementation = "broker";
      systemd.user.services.dbus-broker.environment.XDG_DATA_DIRS = "/run/current-system/sw/share";

      # Activation-only: nothing pulls this in, the bus is meant to start it.
      systemd.user.services."app-${busName}" = {
        description = "TestApp";
        serviceConfig = {
          Type = "dbus";
          BusName = busName;
          ExecStart = "${testApp}/bin/test-app";
        };
      };

      # Stands in for a shell that forks the desktop entry's Exec= itself.
      systemd.user.services.fake-shell = {
        wantedBy = [ "default.target" ];
        serviceConfig.ExecStart = "${pkgs.writeShellScript "fake-shell" ''
          while [ ! -e "$XDG_RUNTIME_DIR/launch" ]; do ${pkgs.coreutils}/bin/sleep 0.2; done
          ${testApp}/bin/test-app &
          exec ${pkgs.coreutils}/bin/sleep infinity
        ''}";
      };
    };

  testScript = ''
    bus_name = "org.example.TestApp"
    unit = f"app-{bus_name}.service"
    desktop = "/run/current-system/sw/share/applications/" + bus_name + ".desktop"

    def as_alice(args):
        return (
            "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 "
            "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus " + args
        )

    def uctl(args):
        return machine.succeed(as_alice("systemctl --user " + args)).strip()

    def name_owner():
        out = machine.succeed(as_alice(
            "gdbus call --session --dest org.freedesktop.DBus "
            "--object-path /org/freedesktop/DBus "
            "--method org.freedesktop.DBus.GetConnectionUnixProcessID " + bus_name
        ))
        return out.strip().lstrip("(uint32 ").rstrip(",)")

    machine.wait_for_unit("multi-user.target", timeout=90)
    machine.wait_for_unit("user@1000.service", timeout=60)
    machine.wait_until_succeeds("test -S /run/user/1000/bus", timeout=30)

    with subtest("the name is activatable and the unit is not running yet"):
        activatable = machine.succeed(as_alice(
            "gdbus call --session --dest org.freedesktop.DBus "
            "--object-path /org/freedesktop/DBus "
            "--method org.freedesktop.DBus.ListActivatableNames"
        ))
        print("ListActivatableNames:", activatable)
        t.assertIn(bus_name, activatable)
        t.assertEqual(uctl(f"show -p ActiveState --value {unit}"), "inactive")

    with subtest("a GLib launch of the entry activates the unit, not a fork"):
        machine.succeed(as_alice(f"gio launch {desktop}"))
        machine.wait_until_succeeds(as_alice(f"systemctl --user is-active {unit}"), timeout=30)

        pid = name_owner()
        cgroup = machine.succeed(f"cat /proc/{pid}/cgroup").strip()
        t.assertIn(
            f"/{unit}",
            cgroup,
            f"app (pid {pid}) should be in its own unit, got: {cgroup}",
        )

    with subtest("forking Exec= instead leaves the unit unused"):
        uctl(f"stop {unit}")
        machine.wait_until_fails(as_alice(f"systemctl --user is-active {unit}"), timeout=30)

        machine.succeed("runuser -u alice -- touch /run/user/1000/launch")
        machine.wait_until_succeeds(as_alice(
            "gdbus call --session --dest org.freedesktop.DBus "
            "--object-path /org/freedesktop/DBus "
            "--method org.freedesktop.DBus.NameHasOwner " + bus_name
        ) + " | grep -q true", timeout=30)

        pid = name_owner()
        cgroup = machine.succeed(f"cat /proc/{pid}/cgroup").strip()
        t.assertIn(
            "/fake-shell.service",
            cgroup,
            f"forked app (pid {pid}) should sit in the shell's cgroup, got: {cgroup}",
        )
        t.assertEqual(
            uctl(f"show -p ActiveState --value {unit}"),
            "inactive",
            f"{unit} should stay unused when the entry is forked instead of activated",
        )
  '';
}
