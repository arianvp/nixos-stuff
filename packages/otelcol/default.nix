{
  lib,
  stdenv,
  buildGoModule,
  go,
  git,
  cacert,
  formats,
  installShellFiles,
  opentelemetry-collector-builder,
}:
let
  name = "otelcol";
  inherit (opentelemetry-collector-builder) version;
  stableVersion = "1.61.0";

  core = "go.opentelemetry.io/collector";
  contrib = "github.com/open-telemetry/opentelemetry-collector-contrib";
  gomods = map (gomod: { inherit gomod; });

  manifest = (formats.yaml { }).generate "manifest.yaml" {
    dist = {
      module = "github.com/arianvp/nixos-stuff/otelcol";
      inherit name version;
      description = "OpenTelemetry Collector with only the components nixos-stuff uses";
      output_path = "./_build";
      build_tags = "grpcnotrace";
    };
    receivers = gomods [
      "${core}/receiver/otlpreceiver v${version}"
      "${contrib}/receiver/hostmetricsreceiver v${version}"
      "${contrib}/receiver/journaldreceiver v${version}"
    ];
    processors = gomods [
      "${core}/processor/batchprocessor v${version}"
      "${contrib}/processor/resourcedetectionprocessor v${version}"
    ];
    exporters = gomods [
      "${core}/exporter/otlpexporter v${version}"
      "${core}/exporter/otlphttpexporter v${version}"
    ];
    extensions = gomods [
      "${contrib}/extension/bearertokenauthextension v${version}"
      "${contrib}/extension/storage/filestorage v${version}"
    ];
    connectors = gomods [
      "${contrib}/connector/grafanacloudconnector v${version}"
    ];
    # The NixOS module passes --config=file:... and validates with --set, which needs yaml.
    providers = gomods [
      "${core}/confmap/provider/envprovider v${stableVersion}"
      "${core}/confmap/provider/fileprovider v${stableVersion}"
      "${core}/confmap/provider/yamlprovider v${stableVersion}"
    ];
  };

  # ocb resolves the module graph with `go mod tidy`, so generating the source needs network.
  src = stdenv.mkDerivation {
    pname = "${name}-src";
    inherit version;

    dontUnpack = true;

    nativeBuildInputs = [
      cacert
      git
      go
    ];

    buildPhase = ''
      export HOME=$NIX_BUILD_TOP/home
      export GOPATH=$NIX_BUILD_TOP/go
      ${lib.getExe opentelemetry-collector-builder} --skip-compilation --config ${manifest}
    '';

    installPhase = ''
      mv _build $out
    '';

    outputHash = "sha256-OMyErmueTds9q4QlXvOWqiIsETQ9mFKucvnpKHr+Ewg=";
    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
  };
in
buildGoModule {
  pname = name;
  inherit version src;

  vendorHash = "sha256-WbJ6F0fD+8sCyJzvn+aZ/bxV4wA3ROp5ggL4zz8Vops=";

  nativeBuildInputs = [ installShellFiles ];

  # https://github.com/open-telemetry/opentelemetry-collector/blob/main/CONTRIBUTING.md#using-cgo
  env.CGO_ENABLED = 0;

  tags = [ "grpcnotrace" ];

  ldflags = [
    "-s"
    "-w"
  ];

  postInstall = ''
    installShellCompletion --cmd ${name} \
      --bash <($out/bin/${name} completion bash) \
      --fish <($out/bin/${name} completion fish) \
      --zsh <($out/bin/${name} completion zsh)
  '';

  passthru = { inherit manifest; };

  meta = {
    description = "OpenTelemetry Collector with only the components nixos-stuff uses";
    homepage = "https://github.com/open-telemetry/opentelemetry-collector";
    license = lib.licenses.asl20;
    mainProgram = name;
  };
}
