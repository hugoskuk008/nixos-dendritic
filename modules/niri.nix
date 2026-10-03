{user, ...}: {


flake.modules.nixos.niri = {pkgs, config ,user,...}: {
 
services.greetd = {
  enable = true;
  settings = {
    default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = user;
    };
  };
};

programs.niri.enable = true;

security.polkit.enable = true; # polkit
services.gnome.gnome-keyring.enable = true; # secret service
security.pam.services.swaylock = {};

programs.waybar.enable = true; # top bar
environment.systemPackages = with pkgs; [ alacritty fuzzel swaylock mako swayidle ];


  };

  flake.modules.homeManager.niri = {pkgs, ...}: 
  {
      home.packages = with pkgs; [
  xwayland-satellite # xwayland supporti
  swaybg
  rofi
  brightnessctl
  fuzzel
  ];


  xdg.configFile."niri".source = ../config/niri;
  xdg.configFile."rofi".source = ../config/rofi;
  };
}
