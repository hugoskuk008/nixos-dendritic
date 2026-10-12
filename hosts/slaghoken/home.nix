{ config, inputs, ... }:

let
  system = "x86_64-linux";
  args = {
    configname = "slaghoken";
    user = "admin";
    sopsSshkey = "/home/admin/.ssh/slaghoken";
  };
in
{
  flake.homeConfigurations.slaghoken =
    inputs.home-manager.lib.homeManagerConfiguration {
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      extraSpecialArgs = args;

      modules = [
        config.flake.modules.homeManager.nvim
        config.flake.modules.homeManager.hyprland
        config.flake.modules.homeManager.zsh
        config.flake.modules.homeManager.Slaghoken

        {
          home.username = "admin";
          home.homeDirectory = "/home/admin";
          home.stateVersion = "26.05";
        }
      ];
    };
}

