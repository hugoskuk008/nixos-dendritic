# nix-build / callPackage expression for modules-ctl and its GTK front end, modules-ctl-gui.
#
# `nix` and `git` are deliberately not wrapped in: the tool must talk to the same nix as the
# user's session, and it only calls git inside a repository, where git already exists.
{
  lib,
  python3Packages,
  wrapGAppsHook4,
  gobject-introspection,
  gtk4,
}:

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

  # GTK needs its typelibs and schemas on the environment of modules-ctl-gui.
  nativeBuildInputs = [ wrapGAppsHook4 gobject-introspection ];
  buildInputs = [ gtk4 ];
  dependencies = [ python3Packages.pygobject3 ];
  dontWrapGApps = true;
  preFixup = ''
    makeWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  # The unit tests never import GTK, so they run without a display.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python -m unittest discover --start-directory tests --top-level-directory .
    runHook postCheck
  '';

  pythonImportsCheck = [ "modules_ctl" ];

  meta = {
    description = "Choose which dendritic modules each host imports, as data";
    mainProgram = "modules-ctl";
  };
}
