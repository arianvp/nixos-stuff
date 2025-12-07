{ lib, pkgs }:

let
  format = pkgs.formats.yaml { };
  
  execEnvVarType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the environment variable";
      };
      
      value = lib.mkOption {
        type = lib.types.str;
        description = "Value of the environment variable";
      };
    };
  };
  
  serviceAccountTokenAttributesType = lib.types.submodule {
    freeformType = format.type;
    
    options = {
      serviceAccountTokenAudience = lib.mkOption {
        type = lib.types.str;
        description = "The intended audience of the token (required)";
        example = "sts.amazonaws.com";
      };
      
      cacheType = lib.mkOption {
        type = lib.types.enum [ "Token" "ServiceAccount" ];
        description = "The type of cache key to use for credential caching (required)";
      };
      
      requireServiceAccount = lib.mkOption {
        type = lib.types.bool;
        description = "Whether the plugin requires a service account to be present";
      };
      
      requiredServiceAccountAnnotationKeys = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Annotation keys that must be present on the service account";
        example = [ "eks.amazonaws.com/role-arn" ];
      };
      
      optionalServiceAccountAnnotationKeys = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Annotation keys that may be present on the service account";
      };
    };
  };
  
  credentialProviderType = lib.types.submodule {
    freeformType = format.type;
    
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the credential provider executable (required)";
        example = "ecr-credential-provider";
      };
      
      matchImages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of image patterns that will use this provider (required)";
        example = [ "*.dkr.ecr.*.amazonaws.com" "*.dkr.ecr.*.amazonaws.com.cn" ];
      };
      
      defaultCacheDuration = lib.mkOption {
        type = lib.types.str;
        description = "Default duration to cache credentials from this provider (required)";
        example = "12h";
      };
      
      apiVersion = lib.mkOption {
        type = lib.types.str;
        description = "API version for CredentialProviderRequest/Response (required)";
        default = "credentialprovider.kubelet.k8s.io/v1";
        example = "credentialprovider.kubelet.k8s.io/v1";
      };
      
      args = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Arguments to pass when executing the plugin binary";
        example = [ "--v=2" "--region=us-west-2" ];
      };
      
      env = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf execEnvVarType);
        default = null;
        description = "Environment variables to set when executing the plugin";
      };
      
      tokenAttributes = lib.mkOption {
        type = lib.types.nullOr serviceAccountTokenAttributesType;
        default = null;
        description = "Configuration for service account tokens passed to the plugin";
      };
    };
  };
  
  credentialProviderConfigType = lib.types.submodule {
    freeformType = format.type;
    
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "kubelet.config.k8s.io/v1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "CredentialProviderConfig";
        description = "Resource kind";
      };
      
      providers = lib.mkOption {
        type = lib.types.listOf credentialProviderType;
        description = "List of credential provider plugins to enable (required)";
      };
    };
  };
in
{
  type = credentialProviderConfigType;
  generate = name: value: format.generate name value;
}
