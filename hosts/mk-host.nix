# Builds a nixosSystem. A host chooses, per kind of module, who decides what is imported:
#
#   the module switcher   pass `selection = ./modules.json;` (the file tools/modules-ctl edits)
#   the host, by hand     pass `nixosModules` / `homeManagerModules` as lists, exactly like
#                         `with config.flake.modules.nixos; [ bootloader system ]`
#
# A hand-written list replaces the selection for its kind, so no module is imported twice.
# Mixing is fine across kinds: for example the switcher for nixos, a list for homeManager.
#
# In modules.json, `enabled` modules are imported, `disabled` ones are deliberately off, and
# registered modules in neither list are not imported and produce a build warning.
{ config, inputs }:
{
  # Directory name under hosts/, as passed to `modules-ctl --host`.
  name,
  # Login user whose Home Manager configuration receives the homeManager modules.
  user,
  specialArgs,
  # Opt in to the module switcher by pointing at this host's modules.json.
  selection ? null,
  # Hand-written module lists. null means "not hand-managed".
  nixosModules ? null,
  homeManagerModules ? null,
  # Hardware, host-specific options and anything else not chosen from the registry.
  extraModules ? [ ],
}:
let
  lib = inputs.nixpkgs.lib;

  chosen = if selection == null then null else builtins.fromJSON (builtins.readFile selection);
  handWritten = { nixos = nixosModules; homeManager = homeManagerModules; };
  kinds = builtins.attrNames handWritten;

  registeredModules = kind: config.flake.modules.${kind};

  moduleNamed = kind: moduleName:
    (registeredModules kind).${moduleName} or (throw ''
      host '${name}': modules.json enables ${kind} module '${moduleName}', which no file registers.
      Remove it with: modules-ctl --host ${name} prune'');

  isChosenBySwitcher = kind: chosen != null && handWritten.${kind} == null;

  modulesFor = kind:
    if handWritten.${kind} != null then handWritten.${kind}
    else if isChosenBySwitcher kind then map (moduleNamed kind) chosen.${kind}.enabled
    else [ ];

  undecidedModuleNames = kind:
    lib.subtractLists
      (chosen.${kind}.enabled ++ chosen.${kind}.disabled)
      (builtins.attrNames (registeredModules kind));

  undecidedModuleWarnings = lib.concatMap
    (kind: map
      (moduleName: "host '${name}': new ${kind} module '${moduleName}' is neither enabled nor disabled (see: modules-ctl --host ${name} status)")
      (undecidedModuleNames kind))
    (builtins.filter isChosenBySwitcher kinds);
in
inputs.nixpkgs.lib.nixosSystem {
  inherit specialArgs;
  modules =
    [ inputs.home-manager.nixosModules.home-manager ]
    ++ modulesFor "nixos"
    ++ extraModules
    ++ [
      {
        warnings = undecidedModuleWarnings;
        home-manager.users.${user}.imports = modulesFor "homeManager";
      }
    ];
}
