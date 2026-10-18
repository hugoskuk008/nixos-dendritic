# nix-build / callPackage expression for modules-ctl.
#
# `nix` and `git` are deliberately not wrapped in: the tool must talk to the same nix as the
# user's session, and it only calls git inside a repository, where git already exists.
{ lib, python3Packages }:

python3Packages.buildPythonApplication {
  pname = "modules-ctl";
  version = "0.1.0";
  pyproject = true;

  # Only Python sources and pyproject.toml, so stray files such as __pycache__ or this
  # expression do not change the build.
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./pyproject.toml
      (lib.fileset.fileFilter (file: file.hasExt "py") ./src)
      (lib.fileset.fileFilter (file: file.hasExt "py") ./tests)
    ];
  };

  build-system = [ python3Packages.setuptools ];

  propagatedBuildInputs = [ python3Packages.tkinter ];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python -m unittest discover --start-directory tests --top-level-directory .
    runHook postCheck
  '';

  pythonImportsCheck = [ "modules_ctl" ];

  meta = {
    description = "Choose which dendritic modules each host imports, as json";
    mainProgram = "modules-ctl";
  };
}
