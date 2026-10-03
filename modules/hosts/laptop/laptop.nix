{ config, inputs, ... }: {

  flake.nixosConfigurations.laptop = inputs.nixpkgs.lib.nixosSystem {
    
    modules = [
      ../../../hosts/laptop/hardware-configuration.nix
      ../../../hosts/laptop/specialisation.nix
      inputs.home-manager.nixosModules.home-manager
      config.flake.modules.nixos.bootloader
      config.flake.modules.nixos.locale
      config.flake.modules.nixos.system
      config.flake.modules.nixos.gnome
      config.flake.modules.nixos.nvim
      config.flake.modules.nixos.steam
      config.flake.modules.nixos.dgpuService
  #    config.flake.modules.nixos.hyprland
  #     config.flake.modules.nixos.niri
{
        programs.firefox.enable=true;
        nixpkgs.hostPlatform = "x86_64-linux";  
             networking.hostName = "Laptroll"; # Define your hostname.
             networking.networkmanager.enable = true;
             hardware.enableRedistributableFirmware = true;
          services.xserver.videoDrivers = ["amdgpu"];
          services.sshd.enable = true;
      #    services.asusd.enable = true;
        users.users.admin = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          };
    home-manager.users.admin = {
      imports = [
      config.flake.modules.homeManager.nvim
      config.flake.modules.homeManager.gnome
      config.flake.modules.homeManager.hyprland-laptroll
      config.flake.modules.homeManager.niri
      ];

      home.stateVersion = "26.05";
          };
        
      }
    ];
  };
}   
