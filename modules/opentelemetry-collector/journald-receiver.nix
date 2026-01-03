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
          copyIfNotNil = from: to: {
            type = "copy";
            inherit from to;
            "if" = "${from} != nil";
          };
          copyFromAttr = fromAttr: copyIfNotNil ''attributes["${fromAttr}"]'';
          # moveToAttr = from: to: moveIfNotNil from ''attributes["${to}"]'';
          copyAttr = from: to: copyFromAttr from ''attributes["${to}"]'';
          copyResource = from: to: {
	    type = "copy";
	    from = ''attributes["${from}"]'';
	    to = ''resource["${to}"]'';
	    "if" = ''attributes["${from}"] != nil'';
	  };
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
              debug = 7; # Debug: debug-level messages
              info = 6; # Informational: informational messages
              info2 = 5; # Notice: normal but significant condition
              warn = 4; # Warning: warning conditions
              error = 3; # Error: error conditions
              error2 = 2; # Critical: critical conditions
              fatal = 1; # Alert: action must be taken immediately
              fatal4 = 0; # Emergency: system is unusable
            };
            "if" = ''attributes["PRIORITY"] != nil'';
          }
          (copyAttr "__CURSOR" "log.record.uid")
          (copyAttr "CODE_FILE" "code.filepath")
          (copyAttr "CODE_FUNC" "code.function")
          (copyAttr "CODE_LINE" "code.lineno")
          (copyAttr "TID" "thread.id")

          (copyAttr "_TRANSPORT" "log.iostream")
          (copyAttr "_STREAM_ID" "systemd.stream.id")

          # The message type
          # TODO: SemConv equiv?
          (copyAttr "MESSAGE_ID" "systemd.message.id")
          (copyAttr "ERRNO" "systemd.errno")

          # systemd
          (copyAttr "INVOCATION_ID" "systemd.invocation.id")
          (copyAttr "USER_INVOCATION_ID" "systemd.user.invocation.id")
          (copyAttr "UNIT" "systemd.unit")

          # TODO: find semantic variant
          (copyAttr "DOCUMENTATION" "systemd.documentation")

          # delegated
          (copyAttr "OBJECT_PID" "process.pid")
          (copyAttr "OBJECT_CWD" "process.working_directory")
          (copyAttr "OBJECT_EXE" "process.executable.path")
          (copyAttr "OBJECT_CMDLINE" "process.command_line")
          (copyAttr "OBJECT_UID" "process.user.id")
          (copyAttr "OBJECT_GID" "process.group.id")
          (copyAttr "OBJECT_SYSTEMD_CGROUP" "process.linux.cgroup")
          (copyAttr "OBJECT_CAP_EFFECTIVE" "process.capabilities.effective")
          (copyAttr "OBJECT_SYSTEMD_UNIT" "systemd.unit")
          (copyAttr "OBJECT_SYSTEMD_SLICE" "systemd.slice")
          (copyAttr "OBJECT_SYSTEMD_INVOCATION_ID" "systemd.invocation.id")

          # coredump-delegated
          (copyAttr "COREDUMP_PID" "process.pid")
          (copyAttr "COREDUMP_CWD" "process.working_directory")
          (copyAttr "COREDUMP_COMM" "process.executable.name")
          (copyAttr "COREDUMP_EXE" "process.executable.path")
          (copyAttr "COREDUMP_CMDLINE" "process.command_line")
          (copyAttr "COREDUMP_UID" "process.user.id")
          (copyAttr "COREDUMP_GID" "process.group.id")
          (copyAttr "COREDUMP_CGROUP" "process.linux.cgroup")
          (copyAttr "COREDUMP_UNIT" "systemd.unit")
          (copyAttr "COREDUMP_SLICE" "systemd.slice")

          # TODO: Bit of a bitch to map to
          # https://opentelemetry.io/docs/specs/semconv/registry/attributes/process/#process-environment-variable
          # due to it not being a map
          # COREDUMP_ENVIRON



          # Resource attributes - process
          (copyResource "_HOSTNAME" "host.name")
          (copyResource "_MACHINE_ID" "host.id")
          (copyResource "_PID" "process.pid")

          # TODO: Find semantic convention version of this
          (copyResource "_BOOT_ID" "systemd.boot.id")

          # TODO: HUH These are not in https://opentelemetry.io/docs/specs/semconv/resource/process/#selecting-process-attributes
          (copyResource "_UID" "process.user.id")
          (copyResource "_GID" "process.group.id")

          (copyResource "_EXE" "process.executable.path")
          (copyResource "_COMM" "process.executable.name")
          (copyResource "_CMDLINE" "process.command_line")

          (copyResource "_SYSTEMD_CGROUP" "process.linux.cgroup")

          # NOTE: Made this one up
          (copyResource "_CAP_EFFECTIVE" "process.capabilities.effective")

          # TODO: What to do with SYSLOG_IDENTIFIER?

          (copyResource "_SYSTEMD_CGROUP" "systemd.cgroup")
          (copyResource "_SYSTEMD_SLICE" "systemd.slice")
          (copyResource "_SYSTEMD_INVOCATION_ID" "systemd.invocation_id")
          (copyResource "_SYSTEMD_UNIT" "systemd.unit")

          # Service identification: use systemd.unit as service.name
          {
            type = "copy";
            from = ''resource["systemd.unit"]'';
            to = ''resource["service.name"]'';
            "if" = ''resource["systemd.unit"] != nil'';
          }
          {
            type = "copy";
            from = ''resource["systemd.invocation_id"]'';
            to = ''resource["service.instance.id"]'';
            "if" = ''resource["systemd.unit"] != nil'';
          }

          # Service identification: use log.iostream (kernel/audit) as service.name
          {
            type = "copy";
            from = ''attributes["log.iostream"]'';
            to = ''resource["service.name"]'';
            "if" = ''attributes["log.iostream"] == "kernel" or attributes["log.iostream"] == "audit"'';
          }
          {
            type = "copy";
            from = ''resource["systemd.boot.id"]'';
            to = ''resource["service.instance.id"]'';
            "if" = ''attributes["log.iostream"] == "kernel" or attributes["log.iostream"] == "audit"'';
          }
        ];
    };
  };

  # Add journald receiver to logs pipeline
  services.opentelemetry-collector.settings.service.pipelines.logs.receivers = [ "journald" ];

  # Add file_storage extension to service extensions
  services.opentelemetry-collector.settings.service.extensions = [ "file_storage/journald" ];
}
