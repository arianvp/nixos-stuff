{ lib, ... }:
{
  name = "hostname";

  nodes.machine = {
    imports = [ ./hostname.nix ];

    system.name = "testmachine";
    networking.dynamicHostName.enable = true;
  };

  testScript = ''
    # Access the machine via the machines dict since networking.hostName is empty
    machine = machines[0]

    with subtest("Dynamic hostname placeholders are resolved"):
        machine.wait_for_unit("multi-user.target")

        # Get the actual hostname
        hostname = machine.succeed("hostname").strip()
        print(f"Dynamic hostname: {hostname}")

        # Verify hostname starts with system.name
        t.assertTrue(hostname.startswith("testmachine-"),
                     f"Expected hostname to start with 'testmachine-', got: {hostname}")

        # Verify the pattern: testmachine-XXXX-XXXX where X is alphanumeric
        pattern = r'^testmachine-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}$'
        t.assertRegex(hostname, pattern,
                      f"Expected hostname to match pattern 'testmachine-XXXX-XXXX', got: {hostname}")

        # Verify placeholders are NOT still present
        t.assertNotIn("????", hostname,
                      f"Placeholders should be resolved, got: {hostname}")
  '';
}
