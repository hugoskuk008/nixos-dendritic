{...}: {

flake.modules.nixos.Slaghoken = {pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lutris
    heroic
    bazaar
    ];
services.flatpak.enable = true;

  };

flake.modules.homeManager.Slaghoken = {pkgs, ...}: {

  home.packages = with pkgs; [
       fastfetch
       fzf
       zoxide
    ];


  };

flake.modules.nixos.Laptop = {pkgs, ...}: {

         environment.systemPackages = with pkgs; [
           discord 
           spotify-qt
         ];
};


}
