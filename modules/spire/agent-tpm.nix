{ lib, pkgs, ... }:
{
  imports = [ ./agent.nix ];
  spire.agent = {
    config = ''
      agent {
        trust_bundle_path = "$CREDENTIALS_DIRECTORY/spire-server-bundle"
        trust_bundle_format = "pem"
      }
      plugins {
        KeyManager "memory" { plugin_data { } }
        NodeAttestor "tpm" {
          plugin_cmd = "${lib.getExe' pkgs.spire-tpm-plugin "tpm_attestor_agent"}"
          plugin_data { }
        }
        WorkloadAttestor "systemd" { plugin_data { } }
      }
    '';
  };
}
