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

    ];


  };




}
