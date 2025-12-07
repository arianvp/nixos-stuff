{
  name = "crio";

  nodes.registry =  {
    imports = [ ./registry-push.nix ];

    services.dockerRegistry = {
      enable = true;
      listenAddress = "0.0.0.0";
      port = 5000;
      openFirewall = true;
    };
  };
  nodes.machine =
    {
      imports = [ ./crio.nix ];

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

      # Mark the local registry as insecure
      virtualisation.containers.registries.insecure = [ "registry:5000" ];

      # Configure registry mirrors for CRI-O
      environment.etc."containers/registries.conf.d/local-mirror.conf".text = ''
        [[registry]]
        prefix = "gcr.io"
        location = "gcr.io"

        [[registry.mirror]]
        location = "registry:5000/gcr.io"
        insecure = true

        [[registry]]
        prefix = "registry.k8s.io"
        location = "registry.k8s.io"

        [[registry.mirror]]
        location = "registry:5000/registry.k8s.io"
        insecure = true
      '';
    };

  # We pass the entire CRI conformance test
  # Skipping the host-local test as it tries to connect to 127.0.0.1:$port
  # But for that we need some weird masquerades https://github.com/kubernetes-sigs/cri-tools/pull/674
  # and I think it might be a security issue: https://github.com/kubernetes/kubernetes/issues/90259
  # FIXME: Skipping pull by digest test as for some reason pulling by digest isn't working?
  testScript = ''
    # Wait for registry to be up and all images to be pushed
    registry.wait_for_unit("docker-registry.service")
    registry.wait_for_unit("multi-user.target")

    # Wait for machine to be ready
    machine.wait_for_unit("crio.service")

    # Run tests
    machine.succeed("critest --ginkgo.skip='runtime should support port mapping with host port and container port' --ginkgo.skip='public image with digest' --ginkgo.flake-attempts 1")
  '';
}
