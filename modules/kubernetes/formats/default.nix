{ lib, pkgs }:

let
  # Filter out null values recursively to avoid empty strings in YAML
  filterNulls = attrs: lib.filterAttrsRecursive (n: v: v != null) attrs;
  
  # Wrapper to add filterNulls to generate functions
  wrapFormat = format: {
    inherit (format) type;
    generate = name: value: format.generate name (filterNulls value);
  } // lib.optionalAttrs (format ? types) {
    inherit (format) types;
  };
in
{
  # Kubeconfig format (client configuration)
  # apiVersion: v1
  # kind: Config
  kubeconfig = wrapFormat (import ./kubeconfig.nix { inherit lib pkgs; });
  
  # Kubelet configuration format
  # apiVersion: kubelet.config.k8s.io/v1beta1
  # kind: KubeletConfiguration
  kubeletConfiguration = wrapFormat (import ./kubelet-config.nix { inherit lib pkgs; });
  
  # Kubelet credential provider configuration
  # apiVersion: kubelet.config.k8s.io/v1
  # kind: CredentialProviderConfig
  kubeletCredentialProviderConfig = wrapFormat (import ./kubelet-credential-provider-config.nix { inherit lib pkgs; });
  
  # Kube-scheduler configuration format
  # apiVersion: kubescheduler.config.k8s.io/v1
  # kind: KubeSchedulerConfiguration
  kubeSchedulerConfiguration = wrapFormat (import ./kube-scheduler-config.nix { inherit lib pkgs; });
  
  # NOTE: kube-controller-manager does NOT support --config flag
  # It only accepts command-line arguments, no config file format available
  
  # Kube-apiserver configuration formats (multiple config types)
  # Returns an attrset with multiple configuration types:
  # - authenticationConfiguration
  # - authorizationConfiguration
  # - admissionConfiguration
  # - encryptionConfiguration
  # - tracingConfiguration
  kubeApiserverConfigurations = let
    raw = import ./kube-apiserver-config.nix { inherit lib pkgs; };
  in {
    authenticationConfiguration = wrapFormat raw.authenticationConfiguration;
    authorizationConfiguration = wrapFormat raw.authorizationConfiguration;
    admissionConfiguration = wrapFormat raw.admissionConfiguration;
    encryptionConfiguration = wrapFormat raw.encryptionConfiguration;
    tracingConfiguration = wrapFormat raw.tracingConfiguration;
  };
}
