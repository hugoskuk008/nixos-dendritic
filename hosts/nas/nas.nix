{ inputs, self,config, ... }:
let
  system = "x86_64-linux";
  args = {
    configname       = "nas";
    user             = "admin";
    sopsSshkey       = "/home/admin/.ssh/slaghoken";
    currentTheme     = "gruvbox";
    internetInterface = "eno1";
  };
  mkHost = import ../mk-host.nix { inherit inputs config; };
in
{
  flake.nixosConfigurations.nas = mkHost {
    name      = "nas";
    inherit (args) user;
    selection = ./modules.json;
    specialArgs = {
      inherit args;
      inherit (args) internetInterface configname user sopsSshkey;
    };
    extraModules = [
      ./hardware-configuration.nix
      ./configuration.nix
      {
        home-manager.useGlobalPkgs               = true;
        home-manager.backupFileExtension         = null;
        home-manager.extraSpecialArgs            = args;
        home-manager.users.${args.user}.home.stateVersion = "26.05";
      }
    ];
  };
}
