{...}: {

flake.modules.nixos.Slaghoken = {pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lutris
    spotify
    heroic
    ];


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
           spotify
         ];
};


}
