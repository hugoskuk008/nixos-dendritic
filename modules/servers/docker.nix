{...}:{
flake.modules.nixos.docker = {user, ...}:{
  virtualtisation.docker.enable = true; 
users.extraGroups.docker.members = ["${user}"];
hardware.nvidia-container-toolkit.enable = true;
virtualtisation.docker.daemon.settings = {
  data-root = /docker/dockerDaemon;
    };
  }; 

}
