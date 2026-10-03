{...}: {

  flake.modules.nixos.hyprland = {pkgs, ...}: {
    programs.hyprland.enable = true;
    
      environment.systemPackages = with pkgs; [
     

      kitty
      rofi
      waybar
        ];


  };


  flake.modules.homeManager.hyprland-slaghoken = {...}:{

      xdg.configFile."hypr/hyprland.lua".source = ../hosts/laptop/hyprland/hyprland.lua;

  };


  flake.modules.homeManager.hyprland-laptroll = {...}: {
      
      xdg.configFile."hypr/hyprland.lua".source = ../hosts/laptop/hyprland/hyprland.lua;
  
  };





}
