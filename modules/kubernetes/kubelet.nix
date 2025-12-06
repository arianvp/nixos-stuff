{ pkgs, ... }:

let
  format = pkgs.formats.yaml { };
  kubeconfigSettings = {
  };
  settings = {
    apiVersion = "kubelet.config.k8s.io/v1beta1";
    kind = "KubeletConfiguration";
    enableServer = true;
    address = "::";
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
}
