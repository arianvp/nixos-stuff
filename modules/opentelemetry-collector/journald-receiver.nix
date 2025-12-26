{ lib, ... }:
let
  copy = from: to: {
    type = "copy";
    inherit from to;
    "if" = "${from} != nil";
  };
  copyAttr = from: to: copy from ''attributes["${to}"]'';
  copyResource = from: to: copy from ''resource["${to}"]'';
in
{
  services.opentelemetry-collector.settings = {
    extensions."file_storage/journald" = {
      directory = "\${env:STATE_DIRECTORY}";
    };

    receivers.journald = {
      directory = "/var/log/journal";
      storage = "file_storage/journald";
      start_at = "end";
      operators = [
        # Log-level attributes (not resource attributes)
        (copyAttr "body.__CURSOR" "log.record.uid")
        {
          type = "severity_parser";
          parse_from = "body.PRIORITY";
          overwrite_text = true;
          mapping = {
            debug = {
              min = 7;
              max = 7;
            };
            info = {
              min = 6;
              max = 6;
            };
            info2 = {
              min = 5;
              max = 5;
            };
            warn = {
              min = 4;
              max = 4;
            };
            error = {
              min = 3;
              max = 3;
            };
            error2 = {
              min = 2;
              max = 2;
            };
            error3 = {
              min = 1;
              max = 1;
            };
            fatal = {
              min = 0;
              max = 0;
            };
          };
          "if" = "body.PRIORITY != nil";
        }

        (copyAttr "body.CODE_FILE" "code.filepath")
        (copyAttr "body.CODE_FUNC" "code.function")
        (copyAttr "body.CODE_LINE" "code.lineno")

        (copyAttr "body.TID" "thread.id")

        (copyAttr "body._TRANSPORT" "log.iostream")
        (copyAttr "body._STREAM_ID" "systemd.stream.id")

        # The message type
        # TODO: SemConv equiv?
        (copyAttr "body.MESSAGE_ID" "systemd.message.id")
        (copyAttr "body.ERRNO" "systemd.errno")

        # systemd
        (copyAttr "body.INVOCATION_ID" "systemd.invocation.id")
        (copyAttr "body.USER_INVOCATION_ID" "systemd.user.invocation.id")
        (copyAttr "body.UNIT" "systemd.unit")
        (copyAttr "body.USER_UNIT" "systemd.user.unit")

        # TODO: find semantic variant
        (copyAttr "body.DOCUMENTATION" "systemd.documentation")

        # delegated
        (copyAttr "body.OBJECT_PID" "process.pid")
        (copyAttr "body.OBJECT_CWD" "process.working_directory")
        (copyAttr "body.OBJECT_EXE" "process.executable.path")
        (copyAttr "body.OBJECT_CMDLINE" "process.command_line")
        (copyAttr "body.OBJECT_UID" "process.user.id")
        (copyAttr "body.OBJECT_GID" "process.group.id")
        (copyAttr "body.OBJECT_SYSTEMD_CGROUP" "process.linux.cgroup")
        # made this one up
        (copyAttr "body.OBJECT_CAP_EFFECTIVE" "process.capabilities.effective")
        (copyAttr "body.OBJECT_SYSTEMD_UNIT" "systemd.unit")
        (copyAttr "body.OBJECT_SYSTEMD_SLICE" "systemd.slice")
        (copyAttr "body.OBJECT_SYSTEMD_INVOCATION_ID" "systemd.invocation.id")

        (copyAttr "body.COREDUMP_PID" "process.pid")
        (copyAttr "body.COREDUMP_CWD" "process.working_directory")
        (copyAttr "body.COREDUMP_COMM" "process.executable.name")
        (copyAttr "body.COREDUMP_EXE" "process.executable.path")
        (copyAttr "body.COREDUMP_CMDLINE" "process.command_line")
        (copyAttr "body.COREDUMP_UID" "process.user.id")
        (copyAttr "body.COREDUMP_GID" "process.group.id")
        (copyAttr "body.COREDUMP_CGROUP" "process.linux.cgroup")
        (copyAttr "body.COREDUMP_UNIT" "systemd.unit")

        (copyAttr "body.COREDUMP_SLICE" "systemd.slice")

        # COREDUMP_SIGNAL_NAME
        # COREDUMP_SIGNAL
        # COREDUMP_CONTAINER_CMDLINE
        # COREDUMP_HOSTNAME
        # COREDUMP_TIMESTAMP
        # NOTE: Bit of a bitch to map to https://opentelemetry.io/docs/specs/semconv/registry/attributes/process/#process-environment-variable due to it not being a map
        # COREDUMP_ENVIRON

        # Resource attributes - process
        (copyResource "body._PID" "process.pid")
        (copyResource "body._UID" "process.user.id")
        (copyResource "body._GID" "process.group.id")
        (copyResource "body._EXE" "process.executable.path")
        (copyResource "body._COMM" "process.executable.name")
        (copyResource "body._CMDLINE" "process.command_line")
        (copyResource "body._CAP_EFFECTIVE" "process.capabilities.effective")
        (copyResource "body._SYSTEMD_CGROUP" "process.linux.cgroup")

        (copyResource "body._SYSTEMD_CGROUP" "systemd.cgroup")
        (copyResource "body._SYSTEMD_SLICE" "systemd.slice")
        (copyResource "body._SYSTEMD_INVOCATION_ID" "systemd.invocation_id")
        (copyResource "body._SYSTEMD_UNIT" "systemd.unit")

        # TODO: Do we actually set service.name? And should we set it to SYSLOG_IDENTIFIER?

        /*
          (copyResource "body._SYSTEMD_UNIT" "service.name")
          {
            type = "move";
            from = "body.SYSLOG_IDENTIFIER";
            to = ''resource["service.name"]'';
            "if" = ''body.SYSLOG_IDENTIFIER != nil && resource["service.name"] == nil'';
          }
          (copyResource "body._SYSTEMD_INVOCATION_ID" "service.instance.id")
        */

        {
          type = "move";
          from = "body";
          to = ''attributes["log.record.original"]'';
        }
        {
          type = "copy";
          from = ''attributes["log.record.original"]["MESSAGE"]'';
          to = "body";
        }
      ];
    };
  };

  # Add journald receiver to logs pipeline
  services.opentelemetry-collector.settings.service.pipelines.logs.receivers = [ "journald" ];

  # Add file_storage extension to service extensions
  services.opentelemetry-collector.settings.service.extensions = [ "file_storage/journald" ];
}
