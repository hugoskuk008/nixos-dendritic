{
flake.modules.nixos.server-bazarr = { config, lib, pkgs, ...}:
  let
   addr= 
    if config.homelab.address == null
    then throw "server-bazarr needs homelab.adress set on this host"
    else config.homelab.address;
   
   appdata = "/docker";
   webPorts = { bazarr = 6767; };
   commonEnv = {PUID = "1000"; PGID = "1000"; TZ = "ETC/UTC";};
  in
   {
      assertions = [{
        assertion = config.virtualisation.docker.enable;
        message = "server-bazarr needs the docker module enabled on this host.";
        }];
      virtualisation.oci-containers.backend = "docker";

      homelab.services = lib.mapAttrs (_ : port: {inherit port;})webPorts;
  
      virtualisation.oci-containers.containers.bazarr = {
        image = "lscr.io/linuxserver/bazarr:latest";
        autoStart = true;
        ports = lib.mapAttrsToList
          (_:p: "${addr}:${toString p}:${toString p}")
          webPorts;
        environment = commonEnv;
        volumes = [
          "${appdata}/bazarr:/config"
          "/data:/data"
      ];
    };
  };
}

