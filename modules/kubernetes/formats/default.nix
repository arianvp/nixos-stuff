{ lib, pkgs }:

{
  # Kubeconfig format (client configuration)
  # apiVersion: v1
  # kind: Config
  kubeconfig = import ./kubeconfig.nix { inherit lib pkgs; };
  
  # Kubelet configuration format
  # apiVersion: kubelet.config.k8s.io/v1beta1
  # kind: KubeletConfiguration
  kubeletConfiguration = import ./kubelet-config.nix { inherit lib pkgs; };
  
  # Kubelet credential provider configuration
  # apiVersion: kubelet.config.k8s.io/v1
  # kind: CredentialProviderConfig
  kubeletCredentialProviderConfig = import ./kubelet-credential-provider-config.nix { inherit lib pkgs; };
  
  # Kube-scheduler configuration format
  # apiVersion: kubescheduler.config.k8s.io/v1
  # kind: KubeSchedulerConfiguration
  kubeSchedulerConfiguration = import ./kube-scheduler-config.nix { inherit lib pkgs; };
  
  # NOTE: kube-controller-manager does NOT support --config flag
  # It only accepts command-line arguments, no config file format available
  
  # Kube-apiserver configuration formats (multiple config types)
  # Returns an attrset with multiple configuration types:
  # - authenticationConfiguration
  # - authorizationConfiguration
  # - admissionConfiguration
  # - encryptionConfiguration
  # - tracingConfiguration
  kubeApiserverConfigurations = import ./kube-apiserver-config.nix { inherit lib pkgs; };
}
