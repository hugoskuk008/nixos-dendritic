{...}: {

flake.modules.nixos.Slaghoken = {pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lutris
    heroic
    bazaar
    prismlauncher
    sops
];
services.flatpak.enable = true;
programs.java = {enable = true; package = pkgs.jdk21;};
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
