{
  name = "kubelet";
  nodes.foo = {
    imports = [
      ../modules/spire/server.nix
      ../modules/spire/agent.nix
      ./kubelet.nix
    ];
  };

  testScript = ''
    foo.wait_for_unit("etcd.service")
    foo.wait_for_unit("kube-apiserver.service")
    foo.wait_for_unit("kubelet.service")
  '';
}
