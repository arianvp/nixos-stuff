# Boots the sandbox under QEMU with the same kernel, initrd, command line and
# read-only drive, and a vsock device, standing in for the Nitro hypervisor,
# and checks that its greeting arrives at the parent's end.
{ guest, ... }:
let
  inherit (guest.config.system.build) nitro-sandbox;
in
{
  name = "nitro-sandbox-guest";

  globalTimeout = 120;

  nodes.machine =
    { pkgs, ... }:
    {
      boot.kernelModules = [ "vhost_vsock" ];
      environment.systemPackages = [
        pkgs.qemu_kvm
        pkgs.socat
      ];
      virtualisation.memorySize = 2048;
      # Lets the sandbox use KVM too, where the host allows nesting.
      virtualisation.qemu.options = [ "-cpu host" ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed(
        "systemd-run --unit=listener socat -u VSOCK-LISTEN:${toString nitro-sandbox.port} CREATE:/tmp/greeting"
    )
    status, _ = machine.execute(
        "timeout 60 qemu-system-x86_64 -accel kvm -accel tcg -m 512 -display none -no-reboot"
        " -serial file:/tmp/console"
        " -kernel ${nitro-sandbox.kernel} -initrd ${nitro-sandbox.initrd}"
        " -append \"$(cat ${nitro-sandbox.cmdline}) console=ttyS0\""
        " -drive if=virtio,format=raw,readonly=on,file=${nitro-sandbox.drive}"
        " -device vhost-vsock-pci,guest-cid=3"
    )
    print(machine.succeed("cat /tmp/console"))
    assert status == 0, f"the sandbox exited with {status}"
    machine.succeed("grep 'Hello from a Nitro Sandbox' /tmp/greeting")
  '';
}
