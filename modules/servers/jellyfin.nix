{...}:{
flake.modules.nixos.server-jellyfin = { config, lib, ... }:
  let
    addr =
      if config.homelab.address == null
      then throw "server-jellyfin needs homelab.address set on this host"
      else config.homelab.address;

    appdata = "/docker/jellyfin";
    webPorts = { jellyfin = 8096; };
  in
  {
    assertions = [{
      assertion = config.virtualisation.docker.enable;
      message = "server-jellyfin needs the Docker module enabled on this host.";
    }];

    virtualisation.oci-containers.backend = "docker";

    homelab.services =
      lib.mapAttrs (_: port: { inherit port; }) webPorts;

    virtualisation.oci-containers.containers.jellyfin = {
      image = "jellyfin/jellyfin:latest";
      autoStart = true;
      user = "1000:1000";

      ports = lib.mapAttrsToList
        (_: port: "${addr}:${toString port}:${toString port}/tcp")
        webPorts
        ++ [ "7359:7359/udp" ];

      volumes = [
        "${appdata}/config:/config"
        "${appdata}/cache:/cache"
        "/data/Media/:/media:ro"
      ];

      # Requires Docker's NVIDIA GPU support to be configured on the host.
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };
  };
}
