{ config, inputs, secrets,... }: 
let
  args = {
  configname = "slaghoken"; 
  user = "admin"; 
  sopsSshkey = "/home/admin/.ssh/slaghoken";
  currentTheme = "gruvbox";
  };
in {
  flake.nixosConfigurations.slaghoken = inputs.nixpkgs.lib.nixosSystem {
   specialArgs = { 
       inherit args; 
       inherit (args) configname user sopsSshkey;};
    modules = (with config.flake.modules.nixos;
[
      inputs.home-manager.nixosModules.home-manager
      bootloader
      system
      locale
      gluetun
      vpn-gui
#      qemu
security
#      gnome
      sops
      ai
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
   home-manager.users.${args.user} = {
      imports = [
      config.flake.modules.homeManager.nvim
#      config.flake.modules.homeManager.gnome
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
  flake.homeConfigurations."admin@slaghoken" =
  inputs.home-manager.lib.homeManagerConfiguration {
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
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

