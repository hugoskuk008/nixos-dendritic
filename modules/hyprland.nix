{ ... }:

{
  flake.modules.nixos.hyprland = { pkgs, ... }: {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = true;
    };

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

  flake.modules.homeManager.hyprland = { configname, user , config, currentTheme, pkgs, lib, ... }: 
let 
reloadHyprland = pkgs.writeShellScript "reload-hyprland" ''
    for rt in /run/user/*; do
      [ -d "$rt/hypr" ] || continue
      for sig in "$rt"/hypr/*; do
        [ -S "$sig/.socket.sock" ] || continue
        XDG_RUNTIME_DIR="$rt" \
        HYPRLAND_INSTANCE_SIGNATURE="''${sig##*/}" \
          ${pkgs.hyprland}/bin/hyprctl reload || true
      done
    done
  '';
in
  {
    programs.zsh.enable = true;

    xdg.configFile."hypr" ={
      source =  ../config/${configname}/hyprland/${currentTheme};
      force = true;
};


    xdg.configFile."kitty"={ 
     source =  ../config/kitty/${currentTheme};
     force = true;  
       };

    
    xdg.configFile."waybar" = {
     source =  ../config/${configname}/waybar/${currentTheme};
     force = true;
    
    };
    xdg.configFile."rofi" = {
    source = ../config/rofi/${currentTheme};
    force = true;  
      };
    
    xdg.configFile."waypaper" = {
      source = ../config/waypaper/${currentTheme};
      force = true;
     };
   
   home.activation.reloadHyprland = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${reloadHyprland}
    '';
    
    
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

