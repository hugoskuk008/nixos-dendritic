{... }:{

  flake.modules.nixos.gnome = {pkgs, ...}: {


     services.xserver.enable = true;
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;
    services.gaze.gnome.enableForUsers = true;
    services.gaze.gnome.gdmFaceLogin = true;
    services.gaze.gnome.enable = true;
    security.pam.services.gaze.simultaneous = true;
  };

  flake.modules.homeManager.gnome = {pkgs, ...}: {
    dconf.settings = {
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";
    };
        home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
    };
  };

}
