# A SPIRE registration entry, as the nodes declare them in
# kubernetes.spire.entries and the server registers them from
# kubernetes.spire.server.entries. The nodes default parentID to their own
# agent; the server takes the entries of every node, so it cannot.
{ lib }:
{
  options = {
    spiffeID = lib.mkOption {
      type = lib.types.str;
      description = "SPIFFE ID of the workload.";
    };

    parentID = lib.mkOption {
      type = lib.types.str;
      description = "SPIFFE ID of the agent the workload runs under.";
    };

    selectors = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Workload selectors.";
    };

    dnsNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "DNS names for the X509-SVID.";
    };

    ipAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "IP addresses for the X509-SVID, which kubernetes.spire.server adds.";
    };
  };
}
