{...}: {

  flake.modules.nixos.hyprland = {pkgs, ...}: {
    programs.hyprland.enable = true;
    services.displayManager.ly.enable = true;
      environment.systemPackages = with pkgs; [
     

      kitty
      rofi
      waybar
        ];


  };


  flake.modules.homeManager.hyprland = {configname, ...}:{

      xdg.configFile."hypr/".source = ../config/${configname}/hyprland;
      xdg.configFile."waybar".source = ../config${configname}/waybar;
  };
}
