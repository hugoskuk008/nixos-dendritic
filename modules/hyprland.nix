{...}: {

  flake.modules.nixos.hyprland = {pkgs, ...}: {
    programs.hyprland.enable = true;
    
      environment.systemPackages = with pkgs; [
     

      kitty
      rofi
      waybar
        ];


  };


  flake.modules.homeManager.hyprland = {configname, ...}:{

      xdg.configFile."hypr/".source = ../config/${configname}/hyprland;

  };
}
