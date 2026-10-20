{...}:{
flake.modules.nixos.flatpak = {pkgs,...}: {

environment.systemPackages = with pkgs; [ bazaar ]; #gnome flatpak gui 
services.flatpak.enable = true;
  };
}
