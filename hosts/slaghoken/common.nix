{user, ...}:{

        nixpkgs.hostPlatform = "x86_64-linux";  
             networking.hostName = "slaghoken"; # Define your hostname.
               
          services.xserver.videoDrivers = ["amdgpu"];
        users.users.${user} = {
          isNormalUser = true;
          extraGroups = [ "wheel" ];
          };
















}
