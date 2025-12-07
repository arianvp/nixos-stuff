{ pkgs, lib, config, ... }:

let
  cfg = config.kubernetes.kubeconfig;
  k8sFormats = import ./formats { inherit lib pkgs; };
  
  # Helper function to generate a kubeconfig file
  mkKubeconfig = name: settings:
    k8sFormats.kubeconfig.generate "${name}.conf" settings;
in
{
  options.kubernetes.kubeconfig = {
    configs = lib.mkOption {
      type = lib.types.attrsOf k8sFormats.kubeconfig.type;
      default = {};
      description = ''
        Kubeconfig files to generate.
        
        Each attribute name becomes the filename (with .conf appended),
        and the value is the kubeconfig configuration.
      '';
      example = lib.literalExpression ''
        {
          admin = {
            apiVersion = "v1";
            kind = "Config";
            current-context = "kubernetes-admin@kubernetes";
            
            clusters = [{
              name = "kubernetes";
              cluster = {
                server = "https://[::1]:6443";
                certificate-authority = "/etc/kubernetes/pki/ca.crt";
              };
            }];
            
            contexts = [{
              name = "kubernetes-admin@kubernetes";
              context = {
                cluster = "kubernetes";
                user = "kubernetes-admin";
              };
            }];
            
            users = [{
              name = "kubernetes-admin";
              user = {
                client-certificate = "/etc/kubernetes/pki/admin.crt";
                client-key = "/etc/kubernetes/pki/admin.key";
              };
            }];
          };
          
          kubelet = {
            # ... kubelet kubeconfig
          };
        }
      '';
    };
    
    installPath = lib.mkOption {
      type = lib.types.str;
      default = "/etc/kubernetes";
      description = "Directory where kubeconfig files will be installed";
    };
  };
  
  config = lib.mkIf (cfg.configs != {}) {
    environment.etc = lib.mapAttrs' (name: settings:
      lib.nameValuePair "kubernetes/${name}.conf" {
        source = mkKubeconfig name settings;
        mode = "0600";
      }
    ) cfg.configs;
  };
}
