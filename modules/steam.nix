{...}:{

flake.modules.nixos.steam = {pkgs, ...}: {

programs.steam = {
  enable = true;
};

environment.systemPackages = with pkgs; [
  protonup-qt
];

programs.gamemode.enable = true;

};
}
