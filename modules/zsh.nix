{...}: {

flake.modules.homeManager.zsh = {config, ...}:{

programs.zsh = {
  enable = true;
  enableCompletion = true;
  autosuggestion.enable = true;
  syntaxHighlighting.enable = true;

  shellAliases = {
    vim = "nvim";
    nrb = "sudo nixos-rebuild switch --flake ~/nixos-dendritic#slaghoken";
  };

  history = {
    size = 10000;
    path = "${config.xdg.dataHome}/zsh/history";
  };

  # Add raw commands that would normally go into .zshrc
  initExtra = ''
  '';
};

programs.zsh.oh-my-zsh = {
  enable = true;
  theme = "robbyrussell";
  plugins = [ "git" "sudo" "docker" ];
};

};
}
