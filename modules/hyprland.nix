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
      mesa-demos
      vulkan-tools
      playerctl
      nerd-fonts.geist-mono
      fira-sans
      font-awesome
    ];
  };

  flake.modules.homeManager.hyprland = { configname, currentTheme, pkgs, ... }: {
    programs.zsh.enable = true;

    xdg.configFile."hypr" ={
      source =  ../config/${configname}/hyprland/${currentTheme};
};
    xdg.configFile."kitty".source =
      ../config/kitty/${currentTheme};

    
    xdg.configFile."waybar" = {
     source =  ../config/${configname}/waybar/${currentTheme};
    
    };
    xdg.configFile."rofi".source = 
      ../config/rofi/${currentTheme};
    
    xdg.configFile."waypaper" = {
      source = ../config/waypaper/${currentTheme};
      onChange = ''
    ${pkgs.waypaper}/bin/waypaper --restore
  '';

    };
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
      awww
      waypaper
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

