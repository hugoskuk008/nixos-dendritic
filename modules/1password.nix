{...}: {

flake.modules.nixos.onePassword = {user, ...}:{
  
  programs._1password.enable = true;
  programs._1password-gui = { 
  
  enable = true;

  polkitPolicyOwners = [ "${user}" ];
    };
  
    environment.etc = {
    "1password/custom_allowed_browsers" = {
      text = ''
        
        '';
      mode = "0755";
    };
  };

  };

}
