{ pkgs, lib, ... }:

{
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
        bind-address = "::";
        # advertise-address = ; auto-detected
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
}
