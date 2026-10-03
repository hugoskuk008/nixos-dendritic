{...}: {


flake.modules.nixos.niri = {pkgs, config ,...}: {
 
services.greetd = {
  enable = true;
  settings = {
    default_session = {
      command = "${config.programs.niri.package}/bin/niri-session";
      user = "admin";
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
    ];


  xdg.configFile."niri".source = ../config/niri;

  };
}
