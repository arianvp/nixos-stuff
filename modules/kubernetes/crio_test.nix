{
  name = "crio";
  nodes.machine =
    {
      imports = [ ./crio.nix ./podman-preload.nix ];

      virtualisation.memorySize = 16384;

      # cri-o tests OOMs too
      boot.kernel.sysctl."vm.panic_on_oom" = 0;

      networking.useNetworkd = true;

      systemd.network.config.networkConfig = {
        # crio cni config creates container bridge that is unmanaged but requires packet forwarding
        # TODO: Use a networkd-managed bridge to fix this
        IPv4Forwarding = "yes";
        IPv6Forwarding = "yes";
      };
    };

  # We pass the entire CRI conformance test
  # Skipping the host-local test as it tries to connect to 127.0.0.1:$port
  # But for that we need some weird masquerades https://github.com/kubernetes-sigs/cri-tools/pull/674
  # and I think it might be a security issue: https://github.com/kubernetes/kubernetes/issues/90259
  testScript = ''
    machine.wait_for_unit("crio.service")
    machine.succeed("critest --ginkgo.skip='runtime should support port mapping with host port and container port' --ginkgo.flake-attempts 1")
  '';
}
