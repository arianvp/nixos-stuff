{
  pkgs,
  lib,
  config,
  ...
}:
{
  services.opentelemetry-collector = {
    enable = true;
    package = pkgs.opentelemetry-collector-contrib;
    settings = {

      # Receivers
      receivers = {
        otlp = {
          protocols = {
            grpc = { };
            http = { };
          };
        };
        hostmetrics = {
          scrapers = {
            cpu = { };
            disk = { };
            load = { };
            memory = { };
            filesystem = { };
            network = { };
            system = { };
          };
        };
      };

      # Processors
      processors = {
        batch = { };
        resourcedetection = {
          detectors = [ "env" ];
          override = false;
        };
      };

      # Service configuration
      service = {
      	# TODO: is this otlp?
      	telemetry.logs.encoding = "json";
        pipelines = {
          # Traces pipeline
          traces = {
            receivers = [ "otlp" ];
            processors = [
              "resourcedetection"
              "batch"
            ];
          };
          # Metrics pipeline
          metrics = {
            receivers = [
              "otlp"
              "hostmetrics"
            ];
            processors = [
              "resourcedetection"
              "batch"
            ];
          };
          # Logs pipeline
          logs = {
            receivers = [ "otlp" ];
            processors = [
              "resourcedetection"
              "batch"
            ];
          };
        };
      };
    };
  };
}
