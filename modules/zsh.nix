{...}: {
flake.modules.nixos.zsh = {pkgs,user,...}:{
  programs.zsh.enable = true;
  environment.shells = [pkgs.zsh];
  users.users.${user}.shell = pkgs.zsh;
  };
flake.modules.homeManager.zsh = {config, pkgs, ...}:{
       home.packages = with pkgs; [
       zoxide
];
programs.zsh = {
  enable = true;
  enableCompletion = true;
  autosuggestion.enable = true;
  syntaxHighlighting.enable = true;

  shellAliases = {
    vim = "nvim";
    nrb = "nh os switch";
  };

  history = {
    size = 10000;
    path = "${config.xdg.dataHome}/zsh/history";
  };
  # Add raw commands that would normally go into .zshrc
  initContent = ''
  
  eval "$(zoxide init zsh)"
  '';
};

programs.zsh.oh-my-zsh = {
  enable = true;
  theme = "robbyrussell";
  plugins = [ "git" "sudo" "docker" ];
};

};
}
