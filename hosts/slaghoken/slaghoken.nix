{ config, inputs, ...}: 
let
  args = {
  configname = "slaghoken"; 
  user = "admin"; 
  sopsSshkey = "/home/admin/.ssh/slaghoken";
  currentTheme = "gruvbox";
  internetInterface = "eno1";
  };
    mkHost = import ../mk-host.nix{inherit config inputs;};

in {
  flake.nixosConfigurations.slaghoken = mkHost {
  name = "slaghoken";
  inherit (args) user;
  selection = ./modules.json;
  specialArgs = { inherit args; inherit (args) internetInterface configname user sopsSshkey; };
  extraModules = [
    ./hardware-configuration.nix
    ./common.nix
    ./nh.nix
  
{
 ai = {
    backend = "llama";
    harness = "hermes";
   };
   services.lact.enable = true;
   home-manager.useGlobalPkgs = true;
   home-manager.backupFileExtension = null;
   home-manager.extraSpecialArgs = args;
      home-manager.users.${args.user}.home.stateVersion = "26.05";



          
 
        
        }
      ];
    };


  }

