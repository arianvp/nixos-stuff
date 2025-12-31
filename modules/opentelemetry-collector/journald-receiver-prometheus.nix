{ lib, ... }:
{
  services.opentelemetry-collector.settings.receivers.journald.operators = lib.mkAfter [
    # Parse Prometheus-style key-value logs
    {
      type = "key_value_parser";
      parse_from = "body";
      delimiter = "=";
      pair_delimiter = " ";
      "if" = ''resource["systemd.unit"] == "prometheus.service"'';
    }

    # Move Prometheus msg to body
    {
      type = "move";
      from = ''attributes["msg"]'';
      to = "body";
      "if" = ''attributes["msg"] != nil'';
    }

    # Move Prometheus err to semantic error attribute
    {
      type = "move";
      from = ''attributes["err"]'';
      to = ''attributes["error.message"]'';
      "if" = ''attributes["err"] != nil'';
    }

    # TODO: Parse Prometheus timestamp
    # {
    #   type = "time_parser";
    #   parse_from = ''attributes["time"]'';
    #   layout = "2006-01-02T15:04:05.999999999Z07:00";
    #   "if" = ''attributes["time"] != nil'';
    # }

    # Parse Prometheus log level to severity (overrides systemd PRIORITY)
    {
      type = "severity_parser";
      parse_from = ''attributes["level"]'';
      preset = "default";
      "if" = ''attributes["level"] != nil'';
    }
  ];
}
