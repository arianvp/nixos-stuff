{
  name = "kubelet";
  nodes.foo = {
    imports = [ ./kubelet.nix ];
  };

  testScript = ''
    foo.wait_for_unit("kubelet.service")
  '';
}
