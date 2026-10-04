{...}: {

flake.modules.homeManager.zsh = {config, ...}:{

programs.zsh = {
  enable = true;
  enableCompletion = true;
  autosuggestions.enable = true;
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
    # Custom shell hooks or exports
    eval "$(zoxide init zsh)"
  '';
};

programs.zsh.ohMyZsh = {
  enable = true;
  theme = "agnoster";
  plugins = [ "git" "sudo" "docker" ];
};

};
}
