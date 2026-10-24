{
flake.modules.nixos.server-lazyLibrarian = { config, lib, pkgs, ...}:
  let
   addr= 
    if config.homelab.address == null
    then throw "server-lazyLibrarian needs homelab.adress set on this host"
    else config.homelab.address;
   
   appdata = "/docker";
   webPorts = { lazyLibrarian = 5299; };
   commonEnv = {PUID = "1000"; PGID = "1000"; TZ = "Europe/Stockholm";};
  in
   {
      assertions = [{
        assertion = config.virtualisation.docker.enable;
        message = "server-bazarr needs the docker module enabled on this host.";
        }];
      virtualisation.oci-containers.backend = "docker";

      homelab.services = lib.mapAttrs (_ : port: {inherit port;})webPorts;
  
      virtualisation.oci-containers.containers.lazyLibrarian = {
        image = "lscr.io/linuxserver/lazylibrarian:latest";
        autoStart = true;
        ports = lib.mapAttrsToList
          (_:p: "${addr}:${toString p}:${toString p}")
          webPorts;
        environment = commonEnv;
        volumes = [
          "${appdata}/lazylibrarian:/config"
          "/data:/data"
      ];
    };
  };
}

