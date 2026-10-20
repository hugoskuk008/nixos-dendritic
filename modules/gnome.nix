{... }:{

  flake.modules.nixos.gnome = {pkgs, ...}: {


     services.xserver.enable = true;
    services.desktopManager.gnome.enable = true;
    services.displayManager.gdm.enable = true;

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
