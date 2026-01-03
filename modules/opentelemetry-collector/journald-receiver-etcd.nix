{ lib, ... }:
{
  services.opentelemetry-collector.settings.receivers.journald.operators = lib.mkAfter [
    # Parse etcd JSON logs
    {
      type = "json_parser";
      parse_from = "body";
      "if" = ''resource["systemd.unit"] == "etcd.service"'';
    }

    # Move etcd msg to body
    {
      type = "move";
      from = ''attributes["msg"]'';
      to = "body";
      "if" = ''attributes["msg"] != nil'';
    }

    # TODO: Parse etcd timestamp
    # {
    #   type = "time_parser";
    #   parse_from = ''attributes["ts"]'';
    #   layout = "2006-01-02T15:04:05.999999999Z07:00";
    #   "if" = ''attributes["ts"] != nil'';
    # }

    # Parse etcd log level to severity (overrides systemd PRIORITY)
    {
      type = "severity_parser";
      parse_from = ''attributes["level"]'';
      preset = "default";
      "if" = ''attributes["level"] != nil'';
    }
  ];
}
