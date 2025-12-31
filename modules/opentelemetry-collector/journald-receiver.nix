{ lib, ... }:
{
  services.opentelemetry-collector.settings = {
    extensions."file_storage/journald" = {
      directory = "\${env:STATE_DIRECTORY}";
    };

    receivers.journald = {
      directory = "/var/log/journal";
      storage = "file_storage/journald";
      start_at = "end";
      operators =

        let
          moveIfNotNil = from: to: {
            type = "move";
            inherit from to;
            "if" = "${from} != nil";
          };
          moveFromAttr = fromAttr: moveIfNotNil ''attributes["${fromAttr}"]'';
          # moveToAttr = from: to: moveIfNotNil from ''attributes["${to}"]'';
          moveAttr = from: to: moveFromAttr from ''attributes["${to}"]'';
          moveResource = from: to: moveFromAttr from ''resource["${to}"]'';
        in

        [
          # from https://www.dash0.com/guides/opentelemetry-journald-receiver
          {
            type = "move";
            from = "body";
            to = ''attributes["body"]'';
          }
          {
            type = "copy";
            from = ''attributes["body"]'';
            to = ''attributes["log.record.original"]'';
          }
          {
            type = "flatten";
            field = ''attributes["body"]'';
          }
          {
            type = "move";
            from = ''attributes["MESSAGE"]'';
            to = "body";
          }
          {
            type = "severity_parser";
            parse_from = ''attributes["PRIORITY"]'';
            overwrite_text = true;
            mapping = {
              debug = 7;
              info = 6;
              info2 = 5;
              warn = 4;
              error = 3;
              error2 = 2;
              error3 = 1;
              fatal = 0;
            };
            "if" = ''attributes["PRIORITY"] != nil'';
          }
          (moveAttr "__CURSOR" "log.record.uid")
          (moveAttr "CODE_FILE" "code.filepath")
          (moveAttr "CODE_FUNC" "code.function")
          (moveAttr "CODE_LINE" "code.lineno")
          (moveAttr "TID" "thread.id")

          (moveAttr "_TRANSPORT" "log.iostream")
          (moveAttr "_STREAM_ID" "systemd.stream.id")

          # The message type
          # TODO: SemConv equiv?
          (moveAttr "MESSAGE_ID" "systemd.message.id")
          (moveAttr "ERRNO" "systemd.errno")

          # systemd
          (moveAttr "INVOCATION_ID" "systemd.invocation.id")
          (moveAttr "USER_INVOCATION_ID" "systemd.user.invocation.id")
          (moveAttr "UNIT" "systemd.unit")

          # TODO: find semantic variant
          (moveAttr "DOCUMENTATION" "systemd.documentation")

          # delegated
          (moveAttr "OBJECT_PID" "process.pid")
          (moveAttr "OBJECT_CWD" "process.working_directory")
          (moveAttr "OBJECT_EXE" "process.executable.path")
          (moveAttr "OBJECT_CMDLINE" "process.command_line")
          (moveAttr "OBJECT_UID" "process.user.id")
          (moveAttr "OBJECT_GID" "process.group.id")
          (moveAttr "OBJECT_SYSTEMD_CGROUP" "process.linux.cgroup")
          (moveAttr "OBJECT_CAP_EFFECTIVE" "process.capabilities.effective")
          (moveAttr "OBJECT_SYSTEMD_UNIT" "systemd.unit")
          (moveAttr "OBJECT_SYSTEMD_SLICE" "systemd.slice")
          (moveAttr "OBJECT_SYSTEMD_INVOCATION_ID" "systemd.invocation.id")

          # coredump-delegated
          (moveAttr "COREDUMP_PID" "process.pid")
          (moveAttr "COREDUMP_CWD" "process.working_directory")
          (moveAttr "COREDUMP_COMM" "process.executable.name")
          (moveAttr "COREDUMP_EXE" "process.executable.path")
          (moveAttr "COREDUMP_CMDLINE" "process.command_line")
          (moveAttr "COREDUMP_UID" "process.user.id")
          (moveAttr "COREDUMP_GID" "process.group.id")
          (moveAttr "COREDUMP_CGROUP" "process.linux.cgroup")
          (moveAttr "COREDUMP_UNIT" "systemd.unit")
          (moveAttr "COREDUMP_SLICE" "systemd.slice")

          # TODO: Bit of a bitch to map to
          # https://opentelemetry.io/docs/specs/semconv/registry/attributes/process/#process-environment-variable
          # due to it not being a map
          # COREDUMP_ENVIRON

          # Resource attributes - process
          (moveResource "_PID" "process.pid")
          (moveResource "_UID" "process.user.id")
          (moveResource "_GID" "process.group.id")
          (moveResource "_EXE" "process.executable.path")
          (moveResource "_COMM" "process.executable.name")
          (moveResource "_CMDLINE" "process.command_line")
          (moveResource "_CAP_EFFECTIVE" "process.capabilities.effective")
          (moveResource "_SYSTEMD_CGROUP" "process.linux.cgroup")

          # TODO: What to do with SYSLOG_IDENTIFIER?

          (moveResource "_SYSTEMD_CGROUP" "systemd.cgroup")
          (moveResource "_SYSTEMD_SLICE" "systemd.slice")
          (moveResource "_SYSTEMD_INVOCATION_ID" "systemd.invocation_id")
          (moveResource "_SYSTEMD_UNIT" "systemd.unit")
        ];
    };
  };

  # Add journald receiver to logs pipeline
  services.opentelemetry-collector.settings.service.pipelines.logs.receivers = [ "journald" ];

  # Add file_storage extension to service extensions
  services.opentelemetry-collector.settings.service.extensions = [ "file_storage/journald" ];
}
