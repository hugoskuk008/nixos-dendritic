{
  flake.modules.nixos.server-radarr = { config, lib, pkgs, ... }:
  let
    addr =
      if config.homelab.address == null
      then throw "server-radarr needs homelab.address set on this host"
      else config.homelab.address;

    appdata = "/docker";

    webPorts = { radarr = 7878; };

    commonEnv = { PUID = "1000"; PGID = "1000"; TZ = "Etc/UTC"; };
  in
  {
    assertions = [{
      assertion = config.virtualisation.docker.enable;
      message = "server-radarr needs the docker module enabled on this host.";
    }];
    virtualisation.oci-containers.backend = "docker";

    homelab.services = lib.mapAttrs (_: port: { inherit port; }) webPorts;

    systemd.tmpfiles.rules = [
      "d ${appdata}/radarr 0750 root root - -"
    ];

    virtualisation.oci-containers.containers.radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      autoStart = true;
      ports = lib.mapAttrsToList
        (_: p: "${addr}:${toString p}:${toString p}")
        webPorts;
      environment = commonEnv;
      volumes = [
        "${appdata}/radarr:/config"
        "/data:/data"
      ];
    };
  };
}
