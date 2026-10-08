{
  lib,
  python3Packages,
  fetchPypi,
  jujutsu,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "jj-stack";
  version = "0.1.7";
  pyproject = true;

  src = fetchPypi {
    pname = "jj_stack";
    inherit (finalAttrs) version;
    hash = "sha256-WGCJUIBxCKoKmYcPeoR2cu4VSN7Jpu099fh4NwBTVnQ=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    httpx2
    markdown-it-py
    pydantic
    rich
  ];

  makeWrapperArgs = [ "--suffix PATH : ${lib.makeBinPath [ jujutsu ]}" ];

  pythonImportsCheck = [ "jj_stack" ];

  meta = {
    description = "Stacked GitHub pull requests for Jujutsu";
    homepage = "https://www.serpentine.com/software/jj-stack/";
    license = lib.licenses.asl20;
    mainProgram = "jj-stack";
  };
})
