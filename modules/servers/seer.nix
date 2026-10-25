{
  flake.modules.nixos.server-seerr = { config, lib, pkgs, ... }:
  let
    addr =
      if config.homelab.address == null
      then throw "server-seerr needs homelab.address set on this host"
      else config.homelab.address;

    appdata = "/docker";

    webPorts = { seerr = 5055; };

    commonEnv = { PUID = "1000"; PGID = "1000"; TZ = "Europe/Stockholm"; };
  in
  {
    assertions = [{
      assertion = config.virtualisation.docker.enable;
      message = "server-radarr needs the docker module enabled on this host.";
    }];
    virtualisation.oci-containers.backend = "docker";

    homelab.services = lib.mapAttrs (_: port: { inherit port; }) webPorts;


    virtualisation.oci-containers.containers.seer = {
      image = "ghcr.io/seerr-team/seerr:latest";
      autoStart = true;
      ports = lib.mapAttrsToList
        (_: p: "${addr}:${toString p}:${toString p}")
        webPorts;
      environment = commonEnv;
      volumes = [
        "${appdata}/seerr:/app/config"
      ];
    };
  };
}
