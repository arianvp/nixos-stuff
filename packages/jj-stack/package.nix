{
  lib,
  python314Packages,
  fetchPypi,
  gitMinimal,
  gnupg,
  jujutsu,
  openssh,
}:

python314Packages.buildPythonApplication (finalAttrs: {
  pname = "jj-stack";
  version = "0.1.6";
  pyproject = true;

  src = fetchPypi {
    pname = "jj_stack";
    inherit (finalAttrs) version;
    hash = "sha256-0PSDJVYNCueOeZkm1dz4M78fgSCGW+4sB6p3VDu/BFY=";
  };

  build-system = [ python314Packages.hatchling ];

  dependencies = with python314Packages; [
    httpx2
    markdown-it-py
    pydantic
    rich
  ];

  # nixpkgs lags behind on httpx2; jj-stack only uses its stable core API.
  pythonRelaxDeps = [ "httpx2" ];

  pythonImportsCheck = [ "jj_stack" ];

  nativeCheckInputs = [
    gitMinimal
    gnupg
    jujutsu
    openssh
  ]
  ++ (with python314Packages; [
    fastapi
    hypothesis
    jsonschema
    pytestCheckHook
    pytest-xdist
  ]);

  enabledTestPaths = [
    "tests/unit"
    "tests/integration"
  ];

  # These write helper scripts with a /usr/bin/env shebang, absent in the sandbox.
  disabledTests = [
    "test_submit_explicit_base_creates_and_updates_only_the_child_stack"
    "test_submit_refreshes_unchanged_pr_text_and_preserves_github_edits"
    "test_submit_describe_with_failure_aborts_before_mutation"
  ];

  postInstall = ''
    mkdir -p $out/share/jj-stack
    cp -r skills $out/share/jj-stack/
  '';

  passthru.skill = "${finalAttrs.finalPackage}/share/jj-stack/skills/jj-stack";

  meta = {
    description = "Stacked GitHub pull requests for Jujutsu";
    homepage = "https://www.serpentine.com/software/jj-stack/";
    license = lib.licenses.asl20;
    mainProgram = "jj-stack";
  };
})
