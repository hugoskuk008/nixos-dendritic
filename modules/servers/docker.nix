{...}:{
flake.modules.nixos.docker = {user, ...}:{
  virtualisation.docker.enable = true; 
users.extraGroups.docker.members = ["${user}"];
hardware.nvidia-container-toolkit.enable = true;

  }; 

}
