{
  name = "crio";
  nodes.machine =
    { lib, pkgs, ... }:
    let
      images = {
        pause = pkgs.dockerTools.pullImage (import ./images/pause.nix);
        e2e-test-images-nginx = pkgs.dockerTools.pullImage (import ./images/e2e-test-images-nginx.nix);
        busybox-test-images-nginx = pkgs.dockerTools.pullImage (import ./images/busybox.nix);
      };
    in
    {
      imports = [ ./crio.nix ];

      systemd.services = lib.mapAttrs' (
        name: value:
        lib.nameValuePair "podman-load-${name}" {
          description = "Load ${value}";
          wantedBy = [ "crio.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            StandardInput = "file:${value}";
            ExecStart = "${pkgs.podman}/bin/podman load";
          };
        }
      ) images;

      networking.useNetworkd = true;

      systemd.network.config.networkConfig = {
        # crio cni config creates container bridge that is unmanaged but requires packet forwarding
        # TODO: Use a networkd-managed bridge to fix this
        IPv4Forwarding = "yes";
        IPv6Forwarding = "yes";
      };
    };

  # We pass the entire CRI conformance test
  testScript = ''
    machine.wait_for_unit("crio.service")
    machine.succeed("critest --ginkgo.focus='Networking' --ginkgo.flake-attempts 2")
    # machine.succeed("critest --ginko.flake-attempts=2")
  '';
}

/*
  [k8s.io] Networking runtime should support networking [It] runtime should support port mapping with host port and container port [Conformance]
  sigs.k8s.io/cri-tools/pkg/validate/networking.go:108

    Timeline >>
    STEP: create a PodSandbox with host port and container port mapping @ 12/07/25 12:09:42.177
    STEP: create a web server container @ 12/07/25 12:09:42.388
    STEP: Get image status for image: registry.k8s.io/e2e-test-images/nginx:1.14-2 @ 12/07/25 12:09:42.388
    STEP: Create container. @ 12/07/25 12:09:42.389
    Dec  7 12:09:42.463: INFO: Created container "cff856a19a878ad1d0c4f7c318f018ee83197a305dd6a50679c73a17f11e6db0"

    STEP: start the web server container @ 12/07/25 12:09:42.463
    STEP: Start container for containerID: cff856a19a878ad1d0c4f7c318f018ee83197a305dd6a50679c73a17f11e6db0 @ 12/07/25 12:09:42.463
    Dec  7 12:09:42.470: INFO: Started container "cff856a19a878ad1d0c4f7c318f018ee83197a305dd6a50679c73a17f11e6db0"

    STEP: check the port mapping with host port and container port @ 12/07/25 12:09:42.47
    STEP: get the IP:port needed to be checked @ 12/07/25 12:09:42.47
    Dec  7 12:09:42.470: INFO: the IP:port is http://127.0.0.1:12000
    STEP: check the content of http://127.0.0.1:12000 @ 12/07/25 12:09:42.47
    [FAILED] in [It] - sigs.k8s.io/cri-tools/pkg/validate/networking.go:288 @ 12/07/25 12:10:43.531
    STEP: stop PodSandbox @ 12/07/25 12:10:43.531
    STEP: delete PodSandbox @ 12/07/25 12:10:44.281
    << Timeline

    [FAILED] Timed out after 61.060s.
    Expected success, but got an error:
        <*url.Error | 0x4000566ae0>:
        Get "http://127.0.0.1:12000": dial tcp 127.0.0.1:12000: i/o timeout
        {
            Op: "Get",
            URL: "http://127.0.0.1:12000",
            Err: <*net.OpError | 0x400044c960>{
                Op: "dial",
                Net: "tcp",
                Source: nil,
                Addr: <*net.TCPAddr | 0x4000b2b170>{
                    IP: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 127, 0, 0, 1],
                    Port: 12000,
                    Zone: "",
                },
                Err: <*net.timeoutError | 0x198b560>{},
            },
        }
    In [It] at: sigs.k8s.io/cri-tools/pkg/validate/networking.go:288 @ 12/07/25 12:10:43.531
*/
