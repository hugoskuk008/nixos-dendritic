{ config, inputs, secrets,... }: 
let
  args = {configname = "slaghoken"; user = "admin";};
in {
  flake.nixosConfigurations.slaghoken = inputs.nixpkgs.lib.nixosSystem {
   specialArgs = { 
       inherit args; 
       inherit secrets;
       inherit (args) configname user;};
    modules = (with config.flake.modules.nixos;
[
      inputs.home-manager.nixosModules.home-manager
      bootloader
      system
      locale
      gluetun
      vpn-gui
      security
#      gnome
      nvim
      steam
      office
      rdp
   hyprland
   firefox
   Slaghoken
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
      config.flake.modules.homeManager.Slaghoken
      ];
      home.stateVersion = "26.05";
          
          };



          
 
        
        }
      ];
    };
  }

