{ ... }:

{
  flake.modules.nixos.hyprland = { pkgs, ... }: {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = true;
    };

    services.displayManager.ly.enable = true;
    services.blueman.enable = true;

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    xdg.portal.enable = true;

    environment.systemPackages = with pkgs; [
      kitty
      rofi
      waybar
      btop
      pavucontrol 
    ];
  };

  flake.modules.homeManager.hyprland = { configname, pkgs, ... }: {
    programs.zsh.enable = true;

    xdg.configFile."hypr".source =
      ../config/${configname}/hyprland;
    xdg.configFile."kitty".source =
      ../config/kitty;
    xdg.configFile."waybar".source =
      ../config/${configname}/waybar;
    xdg.configFile."rofi".source = 
      ../config/rofi;

    home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
    };

    home.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      vesktop
    ];

    fonts.fontconfig.enable = true;

    gtk = {
      enable = true;

      theme = {
        name = "Adwaita-dark";
        package = pkgs.gnome-themes-extra;
      };

      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
      };
    };

    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = "adwaita-dark";
    };

    home.sessionVariables = {
      GTK_THEME = "Adwaita:dark";
      QT_QPA_PLATFORMTHEME = "gtk3";
    };
  };
}

