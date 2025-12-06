{ ... }:

{
  imports = [
    ./etcd.nix
    ./kube-apiserver.nix
    ./kube-scheduler.nix
    ./kube-controller-manager.nix
    ./kubelet.nix
    ./crio.nix
  ];
}
