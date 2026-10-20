{ config, inputs, ... }: 
let
  args = {
  configname = "laptop"; 
  user = "admin"; 
  currentTheme = "gruvbox";};

  mkHost = import ../mk-host.nix{inherit config inputs;};
in {
  flake.nixosConfigurations.Laptroll = mkHost {
  name = "Laptroll";
  inherit (args) user;
  selection = ./modules.json;
  specialArgs = { inherit args; inherit (args) configname user ; };
  extraModules = [
    ./hardware-configuration.nix
    ./specialisation.nix
    ./nh.nix
      
{      boot.blacklistedKernelModules = [ "uvcvideo" ];

      home-manager.extraSpecialArgs = args;
        nixpkgs.hostPlatform = "x86_64-linux";  
             networking.hostName = "Laptroll"; # Define your hostname.
             networking.networkmanager.enable = true;
             hardware.enableRedistributableFirmware = true;
  
          services.xserver.videoDrivers = ["amdgpu"];
      #   services.asusd.enable = true;
        
        users.users.${args.user} = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          };
          
    home-manager.users.${args.user} = {

      home.stateVersion = "26.05";
          };
        
        }
      ];
    };
  }

