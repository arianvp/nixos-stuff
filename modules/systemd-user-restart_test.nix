{
  name = "systemd-user-restart";

  globalTimeout = 240;

  nodes.machine =
    { pkgs, ... }:
    let
      sleep = "${pkgs.coreutils}/bin/sleep";

      # Stands in for a desktop shell that forks an app as a plain child
      # instead of handing it to systemd.
      fakeShell =
        name:
        pkgs.writeShellScript "fake-shell-${name}" ''
          ${sleep} infinity &
          echo $! > "$XDG_RUNTIME_DIR/${name}.app"
          exec ${sleep} infinity
        '';

      shell = name: {
        wantedBy = [ "default.target" ];
        serviceConfig.ExecStart = "${fakeShell name}";
      };
    in
    {
      users.users.alice = {
        isNormalUser = true;
        uid = 1000;
        linger = true;
      };

      systemd.user.services.shell-churn = shell "shell-churn";
      systemd.user.services.shell-pinned = shell "shell-pinned" // {
        restartIfChanged = false;
      };

      # Stands in for a nixpkgs bump: both unit files change, nothing else does.
      specialisation.bumped.configuration = {
        systemd.user.services.shell-churn.environment.BUMPED = "1";
        systemd.user.services.shell-pinned.environment.BUMPED = "1";
      };
    };

  testScript = ''
    units = ["shell-churn", "shell-pinned"]

    def as_alice(args):
        return "runuser -u alice -- env XDG_RUNTIME_DIR=/run/user/1000 " + args

    def uctl(args):
        return machine.succeed(as_alice("systemctl --user " + args)).strip()

    machine.wait_for_unit("multi-user.target", timeout=90)
    machine.wait_for_unit("user@1000.service", timeout=60)

    for unit in units:
        machine.wait_until_succeeds(as_alice(f"systemctl --user is-active {unit}.service"), timeout=30)
        machine.wait_until_succeeds(f"test -s /run/user/1000/{unit}.app", timeout=30)

    apps = {u: machine.succeed(f"cat /run/user/1000/{u}.app").strip() for u in units}
    before = {u: uctl(f"show -p InvocationID --value {u}.service") for u in units}

    with subtest("an app forked by the shell shares the shell's cgroup"):
        for unit, pid in apps.items():
            cgroup = machine.succeed(f"cat /proc/{pid}/cgroup").strip()
            t.assertIn(
                f"/{unit}.service",
                cgroup,
                f"{unit} app (pid {pid}) is not in the shell's cgroup: {cgroup}",
            )

    with subtest("both unit files changed"):
        for unit in units:
            machine.fail(
                "cmp -s "
                f"/run/current-system/etc/systemd/user/{unit}.service "
                f"/run/current-system/specialisation/bumped/etc/systemd/user/{unit}.service"
            )

    print(machine.succeed(
        "/run/current-system/specialisation/bumped/bin/switch-to-configuration test 2>&1"
    ))

    after = {u: uctl(f"show -p InvocationID --value {u}.service") for u in units}

    with subtest("the changed unit is restarted and takes its app with it"):
        t.assertNotEqual(
            before["shell-churn"],
            after["shell-churn"],
            "shell-churn should have been restarted but its InvocationID is unchanged",
        )
        machine.wait_until_fails(f"kill -0 {apps['shell-churn']}", timeout=30)

    with subtest("restartIfChanged = false keeps the unit and its app alive"):
        t.assertEqual(
            before["shell-pinned"],
            after["shell-pinned"],
            "shell-pinned was restarted despite restartIfChanged = false",
        )
        machine.succeed(f"kill -0 {apps['shell-pinned']}")
        t.assertEqual(uctl("is-active shell-pinned.service"), "active")
  '';
}
