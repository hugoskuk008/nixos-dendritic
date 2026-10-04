{...}: {

  flake.modules.nixos.hyprland = {pkgs, ...}: {
    programs.hyprland.enable = true;
    services.displayManager.ly.enable = true;
    services.blueman.enable = true;
    hardware.bluetooth.enable = true;
    hardware.bluetooth.powerOnBoot = true;
    environment.systemPackages = with pkgs; [
     

      kitty
      rofi
      waybar
        ];


  };


  flake.modules.homeManager.hyprland = {configname, ...}:{
      programs.zsh.enable = true;
      xdg.configFile."hypr".source = ../config/${configname}/hyprland;
      xdg.configFile."kitty".source = ../config/kitty;  
        xdg.configFile."waybar".source = ../config/${configname}/waybar;
  };
}
