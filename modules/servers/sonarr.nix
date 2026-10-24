{
flake.modules.nixos.server-sonarr = { config, lib, pkgs, ...}:
  let
   addr= 
    if config.homelab.address == null
    then throw "server-sonarr needs homelab.adress set on this host"
    else config.homelab.address;
   
   appdata = "/docker";
   webPorts = { sonarr = 8989; };
   commonEnv = {PUID = "1000"; PGID = "1000"; TZ = "ETC/UTC";};
  in
   {
      assertions = [{
        assertion = config.virtualisation.docker.enable;
        message = "server-sonarr needs the docker module enabled on this host.";
        }];
      virtualisation.oci-containers.backend = "docker";

      homelab.services = lib.mapAttrs (_ : port: {inherit port;})webPorts;
  
      virtualisation.oci-containers.containers.sonarr = {
        image = "lscr.io/linuxserver/sonarr:latest";
        autoStart = true;
        ports = lib.mapAttrsToList
          (_:p: "${addr}:${toString p}:${toString p}")
          webPorts;
        environment = commonEnv;
        volumes = [
          "${appdata}/sonarr:/config"
          "/data:/data"
      ];
    };
  };
}

