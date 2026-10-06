{ config, inputs, ... }: 
let
  args = {configname = "slaghoken"; user = "admin";};
in {
  flake.nixosConfigurations.slaghoken = inputs.nixpkgs.lib.nixosSystem {
   specialArgs = args; 
    modules = (with config.flake.modules.nixos;
[
      inputs.home-manager.nixosModules.home-manager
      bootloader
      system
      locale
      security
#      gnome
      nvim
      steam
      office
      rdp
   hyprland
   firefox
#     niri
  ])
  ++[
    ./hardware-configuration.nix
    ./common.nix

  
{
  
   home-manager.extraSpecialArgs = args;
   home-manager.users.${args.user} = {
      imports = [
      config.flake.modules.homeManager.nvim
      config.flake.modules.homeManager.gnome
       config.flake.modules.homeManager.hyprland
#      config.flake.modules.homeManager.niri
      config.flake.modules.homeManager.zsh
      ];
      home.stateVersion = "26.05";
          };



          
 
        
        }
      ];
    };
  }

