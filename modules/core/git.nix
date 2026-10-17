{inputs, ...}: {


flake.modules.nixos.git = {user, config, ... }:{
  imports = [inputs.sops-nix.nixosModules.sops]; 
 
 sops.secrets."github/token" = {
    owner = "${user}"; };

 sops.templates."git-credentials" = {
    content = ''
      https://x-access-token:${config.sops.placeholder."github/token"}@github.com
    '';
    path  = "/home/${user}/.config/git/credentials";
    owner = "${user}";
    group = "users";
    mode  = "0600";
  };

 environment.etc."gitconfig".text = ''
      [credential]
          helper = store --file /home/${user}/.config/git/credentials
    '';
  };




}
