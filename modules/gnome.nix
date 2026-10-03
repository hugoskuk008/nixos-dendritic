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
  };

}
