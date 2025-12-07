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

  execConfigType = lib.types.submodule {
    freeformType = format.type;

    options = {
      command = lib.mkOption {
        type = lib.types.str;
        description = "Command to execute (required)";
        example = "/usr/local/bin/k8s-auth-provider";
      };

      apiVersion = lib.mkOption {
        type = lib.types.str;
        description = "API version to use when decoding the ExecCredentials resource (required)";
        example = "client.authentication.k8s.io/v1";
        # TODO: We should put default apiVersions everywhere
        default = "client.authentication.k8s.io/v1";
      };

      args = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Arguments to pass to the command";
        example = [ "--region" "us-west-2" ];
      };

      env = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf execEnvVarType);
        default = null;
        description = "Environment variables to set when executing the plugin";
      };

      provideClusterInfo = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Whether to provide cluster information to the exec plugin";
      };

      installHint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Message to display if the executable is not found";
        example = "Install the aws-iam-authenticator binary from https://example.com";
      };

      interactiveMode = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "Never" "IfAvailable" "Always" ]);
        default = null;
        description = "Defines when stdin should be passed to the exec plugin";
      };
    };
  };

  authProviderConfigType = lib.types.submodule {
    freeformType = format.type;

    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the auth provider (required)";
        example = "oidc";
      };

      config = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.str);
        default = null;
        description = "Auth provider configuration as key-value pairs";
      };
    };
  };

  authInfoType = lib.types.submodule {
    freeformType = format.type;

    options = {
      client-certificate = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a client certificate file for TLS";
        example = "/path/to/client.crt";
      };

      client-certificate-data = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PEM-encoded client certificate data (overrides client-certificate)";
      };

      client-key = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a client key file for TLS";
        example = "/path/to/client.key";
      };

      client-key-data = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PEM-encoded client key data (overrides client-key)";
      };

      token = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Bearer token for authentication";
      };

      tokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a file containing a bearer token";
      };

      as = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Username to impersonate for the operation";
      };

      as-uid = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "UID to impersonate for the operation";
      };

      as-groups = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "Groups to impersonate for the operation";
      };

      username = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Username for basic authentication";
      };

      password = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Password for basic authentication";
      };

      auth-provider = lib.mkOption {
        type = lib.types.nullOr authProviderConfigType;
        default = null;
        description = "Authentication provider configuration";
      };

      exec = lib.mkOption {
        type = lib.types.nullOr execConfigType;
        default = null;
        description = "Exec-based credential provider configuration";
      };
    };
  };

  clusterType = lib.types.submodule {
    freeformType = format.type;

    options = {
      server = lib.mkOption {
        type = lib.types.str;
        description = "The address of the Kubernetes cluster (required)";
        example = "https://1.2.3.4:6443";
      };

      certificate-authority = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to a cert file for the certificate authority";
        example = "/path/to/ca.crt";
      };

      certificate-authority-data = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "PEM-encoded certificate authority certificates (overrides certificate-authority)";
      };

      tls-server-name = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Server name to use for server certificate validation";
        example = "kubernetes.example.com";
      };

      insecure-skip-tls-verify = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Skip TLS certificate verification (insecure)";
      };

      proxy-url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Proxy URL to use for requests";
        example = "http://proxy.example.com:8080";
      };

      disable-compression = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Disable compression for responses from the server";
      };
    };
  };

  contextType = lib.types.submodule {
    freeformType = format.type;

    options = {
      cluster = lib.mkOption {
        type = lib.types.str;
        description = "Name of the cluster for this context (required)";
      };

      user = lib.mkOption {
        type = lib.types.str;
        description = "Name of the user for this context (required)";
      };

      namespace = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default namespace to use for unqualified object names";
        example = "default";
      };
    };
  };

  namedClusterType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the cluster";
        example = "production";
      };

      cluster = lib.mkOption {
        type = clusterType;
        description = "Cluster connection information";
      };
    };
  };

  namedContextType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the context";
        example = "production-admin";
      };

      context = lib.mkOption {
        type = contextType;
        description = "Context configuration";
      };
    };
  };

  namedAuthInfoType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the user/auth info";
        example = "admin";
      };

      user = lib.mkOption {
        type = authInfoType;
        description = "User authentication information";
      };
    };
  };

  kubeconfigType = lib.types.submodule {
    freeformType = format.type;

    options = {
      apiVersion = lib.mkOption {
        type = lib.types.str;
        default = "v1";
        description = "API version";
      };

      kind = lib.mkOption {
        type = lib.types.str;
        default = "Config";
        description = "Resource kind";
      };

      clusters = lib.mkOption {
        type = lib.types.listOf namedClusterType;
        default = [ ];
        description = "List of named cluster configurations";
      };

      contexts = lib.mkOption {
        type = lib.types.listOf namedContextType;
        default = [ ];
        description = "List of named context configurations";
      };

      users = lib.mkOption {
        type = lib.types.listOf namedAuthInfoType;
        default = [ ];
        description = "List of named user/auth info configurations";
      };

      current-context = lib.mkOption {
        type = lib.types.str;
        description = "Name of the context to use by default";
        example = "production-admin";
      };

      preferences = lib.mkOption {
        type = lib.types.nullOr (lib.types.attrsOf lib.types.anything);
        default = null;
        description = "General preferences (deprecated in v1.34)";
      };
    };
  };
in
{
  type = kubeconfigType;
  generate = name: value: format.generate name value;

  # Export reusable types for other modules
  types = {
    inherit clusterType authInfoType contextType execConfigType;
  };
}
