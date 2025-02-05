{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.coredump-upload;
in
{
  options.coredump-upload = {
    bucket = lib.mkOption {
      type = lib.types.str;
      description = "The S3 bucket path to upload coredumps to";
    };
  };
  config = {
    systemd.paths.coredump-upload = {
      wantedBy = [ "paths.target" ];
      description = "Upload coredumps to the server";
      pathConfig.PathChanged = "/var/lib/systemd/coredump";
    };
    systemd.services.coredump-upload = {
      script = ''
        instance_id=$(${pkgs.ec2-utils}/bin/ec2-metadata --instance-id)
        ${pkgs.awscli2}/bin/aws s3 sync /var/lib/systemd/coredump "${cfg.bucket}/$instance_id"
      '';
    };
  };
}
