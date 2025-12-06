{ pkgs, lib, ... }:

let
  format = pkgs.formats.yaml { };

  kubeconfigSettings = {

  };

  settings = {
    apiVersion = "kubelet.config.k8s.io/v1beta1";
    kind = "KubeletConfiguration";
    enableServer = true;
    address = "[::]";
    port = 10250;
    #
    # TODO: Maybe useful if we wanna outsource to spire?
    # tlsCertFile  = "";
    # tlsPrivateKeyFile = "";
    #
    # TODO: Maybe useful if the kube-apiserver supports it
    # rotateCertificates = false;
    # serverTLSBootstrap = false;

    # TODO: Something better
    authentication = {
      anonymous.enabled = true;
      webhook.enabled = false;
    };

    # TODO set to "Webhook"
    authorization.mode = "AlwaysAllow";

    # authentication = {
    # x509 = {
    # clientCAFile = "";
    # };
    # webhook = {
    /*
      bool enabled allows bearer token authentication backed by the
      tokenreviews.authentication.k8s.io API.
    */
    # enabled = false;
    # cacheTTL
    # };
    # anonymous = {
    /*
      bool enabled allows anonymous requests to the kubelet server. Requests
      that are not rejected by another authentication method are treated as
      anonymous requests. Anonymous requests have a username of
      system:anonymous, and a group name of system:unauthenticated.
    */
    # enabled = false;
    # };
    # };
    # authorization = {
    # mode  = "AlwaysEnabled|Webhook"; SubjectAccessReview API or not?
    # };

    # cluster.local is not RFC compliant and interferes with our network's mDNS
    clusterDomain = "cluster.internal";

    # TODO: Mabye? Gotta figure out how systemd-resolved is gonna interact
    # clusterDNS = [];
    #

    cgroupDriver = "systemd";
    # TODO: Figure out what to do with hairpinMode

    # TODO: is this correct?
    resolvConf = "/run/systemd/resolve/resolv.conf";

    containerRuntimeEndpoint = "unix:///run/crio/crio.sock";

    # kubeconfig = format.generate "kubeconfig.yaml" kubeconfigSettings;
  };

  /*
    For my understanding:

    --bootstrap-kubeconfig is the kubeconfig used to talk to the apiserver initially.
    It is used to request a certificate from the apiserver.
    On success, a new kubeconfig will be written to --kubeconfig
  */

  kubeletConfig = format.generate "config.yaml" settings;
in

{

  # TODO: Configure with config file and best practises
  # TODO: not localhost
  systemd.services.etcd = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "notify";
      StateDirectory = "etcd";
      ExecStart = "${pkgs.etcd}/bin/etcd --name %H --data-dir $STATE_DIRECTORY";
    };
  };

  systemd.services.kube-apiserver =

    let
      args = lib.cli.toGNUCommandLineShell { } rec {
        etcd-servers = "http://localhost:2379";
        service-account-issuer = "https://spire.nixos.sh";
        # TODO: delegate signing to SPIRE: https://github.com/kubernetes/enhancements/tree/master/keps/sig-auth/740-service-account-external-signing
        # service-account-signing-endpoint = "/run/signing.sock";
        # Used to verify. When unset; defaults to --tls-private-key-file
        service-account-key-file = "/run/kubernetes/service-account.key";
        # Used to sign
        service-account-signing-key-file = "/run/kubernetes/service-account.key";

        # The default; but conceptually wrong when the issuer is external.
        # TODO: change to the cluster api server address in the future
        api-audiences = [ service-account-issuer ];

        # TODO: Authentication
        # TODO: Authorization
      };
    in

    {
      wantedBy = [ "multi-user.target" ];

      # Fixes: Unable to find suitable network address.error='no default routes
      # found in \"/proc/net/route\" or \"/proc/net/ipv6_route\"'. Try to set the
      # AdvertiseAddress directly or provide a valid BindAddress to fix this.
      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];

      serviceConfig = {
        Type = "notify";
        WatchdogSec = "30s";
        # TODO: Key persistence or out-source to SPIRE
        ExecStartPre = "${pkgs.openssl}/bin/openssl ecparam -genkey -name prime256v1 -out /run/kubernetes/service-account.key";
        ExecStart = "${pkgs.kubernetes}/bin/kube-apiserver ${args}";
        RuntimeDirectory = "kubernetes";
        StateDirectory = "kubernetes";
      };
    };

  systemd.services.kubelet = {
    wantedBy = [ "multi-user.target" ];
    after = [ "crio.service"]; # apparently no socket activ
    serviceConfig = {
      Type = "notify";
      WatchdogSec = "30s";
      StateDirectory = "kubelet";
      # TODO: enable watchdog
      ExecStart = "${pkgs.kubernetes}/bin/kubelet --config ${kubeletConfig}";
    };
  };

  virtualisation.cri-o = {
    enable = true;
  };

}
