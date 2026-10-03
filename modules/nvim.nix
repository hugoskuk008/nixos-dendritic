{...}: {


flake.modules.nixos.nvim = {pkgs, ... }: {

programs.neovim.enable = true;

};

flake.modules.homeManager.nvim = {pkgs, ...}: {

xdg.configFile."nvim".source = ../config/nvim;

home.packages = with pkgs; [
ripgrep
nil
nixpkgs-fmt
nodejs
gcc
];

};

}
