{
  name = "kubelet";
  nodes.foo = {
    imports = [
      ./kubelet.nix
    ];
  };

  testScript = ''
    foo.wait_for_unit("kubelet.service")
    foo.wait_for_unit("etcd.service")
    foo.wait_for_unit("kube-apiserver.service")
  '';
}
