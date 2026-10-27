{...}: {

flake.modules.nixos.Slaghoken = {pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    lutris
    heroic
    prismlauncher
    sops
    wl-clipboard
];
programs.java = {enable = true; package = pkgs.jdk21;};
  };

flake.modules.homeManager.Slaghoken = {pkgs, ...}: {

  home.packages = with pkgs; [
       fastfetch
       fzf
    ];


  };

flake.modules.nixos.Laptop = {pkgs, ...}: {

         environment.systemPackages = with pkgs; [
           discord 
          thunderbird 
         ];
};


}
