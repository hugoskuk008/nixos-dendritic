{
flake.modules.nixos.server-audiobookshelf = { config, lib, pkgs, ...}:
  let
   addr= 
    if config.homelab.address == null
    then throw "server-audiobookshelf needs homelab.adress set on this host"
    else config.homelab.address;
   
   appdata = "/docker";
   webPorts = { audiobookshelf = 13378; };
   commonEnv = {PUID = "1000"; PGID = "1000"; TZ = "Europe/Stockholm";};
  in
   {
      assertions = [{
        assertion = config.virtualisation.docker.enable;
        message = "server-audiobookshelf needs the docker module enabled on this host.";
        }];
      virtualisation.oci-containers.backend = "docker";

      homelab.services = lib.mapAttrs (_ : port: {inherit port;})webPorts;
  
      virtualisation.oci-containers.containers.audiobookshelf = {
        image = "ghcr.io/advplyr/audiobookshelf:latest";
        autoStart = true;
        ports = [
            "${addr}:${toString webPorts.audiobookshelf}:80"
         ];
        environment = commonEnv;
        volumes = [
          "${appdata}/audiobookshelf/config:/config"
          "/data/Media/Audiobooks/:/audiobooks"
          "${appdata}/audiobookshelf/metadata:/metadata"
      ];
    };
  };
}

