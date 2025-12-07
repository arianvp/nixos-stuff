{
  name = "kubernetes";
  
  nodes.foo = {
    imports = [
      ./kubernetes.nix
    ];
    
    # Enable the components
    kubernetes = {
      kube-apiserver.enable = true;
      kube-scheduler.enable = true;
      kube-controller-manager.enable = true;
      kubelet.enable = true;
    };
  };

  testScript = ''
    foo.wait_for_unit("etcd.service")
    foo.wait_for_unit("kube-apiserver.service")
    foo.wait_for_unit("kube-scheduler.service")
    foo.wait_for_unit("kube-controller-manager.service")
    foo.wait_for_unit("kubelet.service")
  '';
}
