{...}: {

flake.modules.nixos.Slaghoken = {pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lutris
    heroic
    ];


  };

flake.modules.homeManager.Slaghoken = {pkgs, ...}: {

  home.packages = with pkgs; [
       fastfetch
       fzf
       zoxide
       spotify
    ];


  };

flake.modules.nixos.Laptop = {pkgs, ...}: {

         environment.systemPackages = with pkgs; [
           discord 
           spotify-qt
         ];
};


}
