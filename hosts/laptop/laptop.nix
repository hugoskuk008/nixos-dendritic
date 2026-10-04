{ config, inputs, ... }: 
let
  args = {configname = "laptop"; user = "admin";};
in {
  flake.nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
   specialArgs = args; 
    modules = (with config.flake.modules.nixos;
[
      inputs.home-manager.nixosModules.home-manager
      bootloader
      system
      locale
      gnome
      nvim
      steam
      dgpuService
      office
      rdp
#   hyprland
#     niri
  ])
  ++[
    ./hardware-configuration.nix
    ./specialisation.nix

  
{
         
      home-manager.extraSpecialArgs = args;
        programs.firefox.enable=true;
        nixpkgs.hostPlatform = "x86_64-linux";  
             networking.hostName = "Laptroll"; # Define your hostname.
             networking.networkmanager.enable = true;
             hardware.enableRedistributableFirmware = true;
  
          services.xserver.videoDrivers = ["amdgpu"];
          services.sshd.enable = true;
      #   services.asusd.enable = true;
        
        users.users.${args.user} = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          };
          
    home-manager.users.${args.user} = {
      imports = [
      config.flake.modules.homeManager.nvim
      config.flake.modules.homeManager.gnome
 #     config.flake.modules.homeManager.hyprland
#      config.flake.modules.homeManager.niri
      ];
      home.stateVersion = "26.05";
          };
        
        }
      ];
    };
  }

