{...}:{
flake.modules.nixos.steamVanilla = {pkgs, ... }: {

programs.steam = {
  enable = true;
  protontricks.enable = true;
};

environment.systemPackages = with pkgs; [
  protonup-qt
];

programs.gamemode.enable = true;




};


}
