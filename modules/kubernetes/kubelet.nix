{ pkgs, ... }:

let
  format = pkgs.formats.yaml { };

  settings = {
    apiVersion = "kubelet.config.k8s.io/v1beta1";
    kind = "KubeletConfiguration";
    enableServer = true;
    # staticPodPath = "";
    # podLogsDir = "/var/log/pods";
    # syncFrequency = "1m";
    # fileCheckFrequency = "20s";
    # httpCheckFrequency  = "20s";
    # staticPodURL = "";
    # staticPodURLHeader = null; # map[string][]string
    address = "[::]";
    # port = 10250;
    #
    # TODO: Maybe useful if we wanna outsource to spire?
    # tlsCertFile  = "";
    # tlsPrivateKeyFile = "";
    #
    # TODO: Maybe useful if the kube-apiserver supports it
    # rotateCertificates = false;
    # serverTLSBootstrap = false;
    #

    # authentication = {
      # x509 = {
        # clientCAFile = "";
      # };
      # webhook = {
        /* bool enabled allows bearer token authentication backed by the
        tokenreviews.authentication.k8s.io API. */
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


    containerRuntimeEndpoint = "/run/this-would-be-a-cri-if-we-had-one.sock";
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
  systemd.services.kubelet = {
    serviceConfig = {
      wantedBy = [ "multi-user.target" ];
      Type = "notify";
      StateDirectory = "kubelet";
      # TODO: enable watchdog
      ExecStart = "${pkgs.kubernetes}/bin/kubelet --config ${kubeletConfig}";
    };
  };
}
