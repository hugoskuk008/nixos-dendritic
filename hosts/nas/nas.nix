{ inputs, self, ... }:
let
  system = "x86_64-linux";
in
{
  flake.nixosConfigurations.nas = inputs.nixpkgs-stable.lib.nixosSystem {
    inherit system;

    specialArgs = {
      inherit inputs;
      # unstable package set, for picking individual packages only
      pkgs-unstable = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    };

    modules = [
      ./configuration.nix
      ./hardware-configuration.nix 

    ];
  };
}
