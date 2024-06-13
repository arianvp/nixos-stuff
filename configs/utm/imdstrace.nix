{ pkgs, ... }:

let
  imdstrace = pkgs.writeText "imdstrace.bt" ''
    kprobe:tcp_connect
    {
        $sock = (struct sock *)arg0;
        $daddr = $sock->__sk_common.skc_daddr;
        $dport = $sock->__sk_common.skc_dport;

        // 169.254.169.254:80 in hexadecimal
        if ($daddr == 0XFEA9FEA9 && $dport == 0x5000)
        {
            // keep a counter per process name
            @[comm,pid] = count();
        }
    }

    interval:s:10
    {
        print(@);
    }
  '';
in
{
  programs.bcc.enable = true;
  environment.systemPackages = [ pkgs.bpftrace ];
  systemd.services.imdstrace = {
    description = "Counts the number of IMDS calls per process";
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.bpftrace pkgs.jq ];
    script = ''
      mkdir -p /etc/metrics
      bpftrace -f json "${imdstrace}" | while read -r metric; do
        echo "$metric"
        if [ $(echo "$metric" | jq -r '.type') = "map" ]; then
          echo "$metric" | jq -r '.data."@" | to_entries | .[] | "imdstrace_conn_total{label=\"" + (.key | gsub("[^a-zA-Z0-9_]+"; "_")) + "\"} " + (.value | tostring)' > "/etc/metrics/imdstrace.prom.$$"
          mv "/etc/metrics/imdstrace.prom.$$" "/etc/metrics/imdstrace.prom"
        fi
      done
    '';
  };
}
