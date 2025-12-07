{ lib, pkgs }:

let
  format = pkgs.formats.yaml { };
  
  # Authentication Configuration Types
  jwtClaimMappingsType = lib.types.submodule {
    freeformType = format.type;
    options = {
      username = lib.mkOption {
        type = lib.types.submodule {
          freeformType = format.type;
          options = {
            claim = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "JWT claim to map to username";
              example = "sub";
            };
            
            expression = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "CEL expression to extract username";
            };
          };
        };
        description = "Username mapping configuration";
      };
      
      groups = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          freeformType = format.type;
          options = {
            claim = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "JWT claim to map to groups";
            };
            
            expression = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "CEL expression to extract groups";
            };
          };
        });
        default = null;
        description = "Groups mapping configuration";
      };
      
      uid = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          freeformType = format.type;
          options = {
            claim = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "JWT claim to map to UID";
            };
            
            expression = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "CEL expression to extract UID";
            };
          };
        });
        default = null;
        description = "UID mapping configuration";
      };
    };
  };
  
  jwtAuthenticatorType = lib.types.submodule {
    freeformType = format.type;
    options = {
      issuer = lib.mkOption {
        type = lib.types.submodule {
          freeformType = format.type;
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "OIDC issuer URL (required)";
              example = "https://issuer.example.com";
            };
            
            audiences = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Acceptable audiences for tokens (required)";
              example = [ "https://kubernetes.default.svc" ];
            };
            
            certificateAuthority = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Base64-encoded PEM CA certificate for validating issuer's TLS cert";
            };
          };
        };
        description = "OIDC issuer configuration (required)";
      };
      
      claimMappings = lib.mkOption {
        type = jwtClaimMappingsType;
        description = "Mappings from JWT claims to user attributes (required)";
      };
      
      claimValidationRules = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf (lib.types.submodule {
          freeformType = format.type;
          options = {
            claim = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "JWT claim to validate";
            };
            
            requiredValue = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Required value for the claim";
            };
            
            expression = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "CEL expression for validation";
            };
            
            message = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Error message if validation fails";
            };
          };
        }));
        default = null;
        description = "Rules for validating JWT claims";
      };
      
      userValidationRules = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf (lib.types.submodule {
          freeformType = format.type;
          options = {
            expression = lib.mkOption {
              type = lib.types.str;
              description = "CEL expression for user validation";
            };
            
            message = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Error message if validation fails";
            };
          };
        }));
        default = null;
        description = "Rules for validating the extracted user information";
      };
    };
  };
  
  anonymousAuthConfigType = lib.types.submodule {
    freeformType = format.type;
    options = {
      enabled = lib.mkOption {
        type = lib.types.bool;
        description = "Enable anonymous authentication (required)";
      };
      
      conditions = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf (lib.types.submodule {
          freeformType = format.type;
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "Path pattern for conditional anonymous access";
            };
          };
        }));
        default = null;
        description = "Path-based conditions for enabling anonymous access";
      };
    };
  };
  
  authenticationConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "apiserver.config.k8s.io/v1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "AuthenticationConfiguration";
        description = "Resource kind";
      };
      
      jwt = lib.mkOption {
        type = lib.types.listOf jwtAuthenticatorType;
        description = "List of JWT authenticators (required, minimum 1)";
      };
      
      anonymous = lib.mkOption {
        type = lib.types.nullOr anonymousAuthConfigType;
        default = null;
        description = "Anonymous authentication configuration";
      };
    };
  };
  
  # Authorization Configuration Types
  webhookAuthorizerType = lib.types.submodule {
    freeformType = format.type;
    options = {
      timeout = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Timeout for webhook requests";
        example = "5s";
      };
      
      authorizedTTL = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "TTL for caching authorized responses";
        example = "5m";
      };
      
      unauthorizedTTL = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "TTL for caching unauthorized responses";
        example = "30s";
      };
      
      subjectAccessReviewVersion = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "API version of SubjectAccessReview to send/receive";
        example = "v1";
      };
      
      matchConditionSubjectAccessReviewVersion = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "API version for match condition SubjectAccessReview";
        example = "v1";
      };
      
      failurePolicy = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "NoOpinion" "Deny" ]);
        default = null;
        description = "Behavior when webhook fails to respond";
      };
      
      connectionInfo = lib.mkOption {
        type = lib.types.submodule {
          freeformType = format.type;
          options = {
            type = lib.mkOption {
              type = lib.types.enum [ "KubeConfigFile" "InClusterConfig" ];
              description = "How to connect to the webhook";
            };
            
            kubeConfigFile = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Path to kubeconfig file (when type=KubeConfigFile)";
            };
          };
        };
        description = "Connection information for the webhook";
      };
    };
  };
  
  authorizerConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "Webhook" "RBAC" "Node" "ABAC" ];
        description = "Type of authorizer (required)";
      };
      
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the authorizer (required, DNS1123 label)";
        example = "webhook-authorizer-1";
      };
      
      webhook = lib.mkOption {
        type = lib.types.nullOr webhookAuthorizerType;
        default = null;
        description = "Webhook configuration (required when type=Webhook)";
      };
    };
  };
  
  authorizationConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "apiserver.config.k8s.io/v1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "AuthorizationConfiguration";
        description = "Resource kind";
      };
      
      authorizers = lib.mkOption {
        type = lib.types.listOf authorizerConfigurationType;
        description = "Ordered list of authorizers (required, minimum 1)";
      };
    };
  };
  
  # Admission Configuration Types
  admissionPluginConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the admission plugin";
        example = "PodSecurity";
      };
      
      path = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to configuration file for the plugin";
      };
      
      configuration = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "Inline configuration for the plugin";
      };
    };
  };
  
  admissionConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "apiserver.config.k8s.io/v1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "AdmissionConfiguration";
        description = "Resource kind";
      };
      
      plugins = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf admissionPluginConfigurationType);
        default = null;
        description = "List of admission plugin configurations";
      };
    };
  };
  
  # Encryption Configuration Types
  aesConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      keys = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          freeformType = format.type;
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the key";
            };
            
            secret = lib.mkOption {
              type = lib.types.str;
              description = "Base64-encoded encryption key";
            };
          };
        });
        description = "List of AES encryption keys";
      };
    };
  };
  
  providerConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      aescbc = lib.mkOption {
        type = lib.types.nullOr aesConfigurationType;
        default = null;
        description = "AES-CBC encryption configuration";
      };
      
      aesgcm = lib.mkOption {
        type = lib.types.nullOr aesConfigurationType;
        default = null;
        description = "AES-GCM encryption configuration";
      };
      
      identity = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "Identity provider (no encryption)";
      };
      
      kms = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "KMS provider configuration";
      };
      
      secretbox = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "Secretbox encryption configuration";
      };
    };
  };
  
  resourceConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      resources = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "List of resource patterns to encrypt";
        example = [ "secrets" "configmaps" ];
      };
      
      providers = lib.mkOption {
        type = lib.types.listOf providerConfigurationType;
        description = "Ordered list of encryption providers";
      };
    };
  };
  
  encryptionConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "apiserver.config.k8s.io/v1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "EncryptionConfiguration";
        description = "Resource kind";
      };
      
      resources = lib.mkOption {
        type = lib.types.listOf resourceConfigurationType;
        description = "List of resource encryption configurations";
      };
    };
  };
  
  # Tracing Configuration Type
  tracingConfigurationType = lib.types.submodule {
    freeformType = format.type;
    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "apiserver.config.k8s.io/v1";
        description = "API version";
      };
      
      kind = lib.mkOption {
        type = lib.types.str;
        default = "TracingConfiguration";
        description = "Resource kind";
      };
      
      endpoint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "OpenTelemetry collector endpoint";
        example = "localhost:4317";
      };
      
      samplingRatePerMillion = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Sampling rate per million requests";
        example = 1000000;
      };
    };
  };
in
{
  # Export all config types
  authenticationConfiguration = {
    type = authenticationConfigurationType;
    generate = name: value: format.generate name value;
  };
  
  authorizationConfiguration = {
    type = authorizationConfigurationType;
    generate = name: value: format.generate name value;
  };
  
  admissionConfiguration = {
    type = admissionConfigurationType;
    generate = name: value: format.generate name value;
  };
  
  encryptionConfiguration = {
    type = encryptionConfigurationType;
    generate = name: value: format.generate name value;
  };
  
  tracingConfiguration = {
    type = tracingConfigurationType;
    generate = name: value: format.generate name value;
  };
}
