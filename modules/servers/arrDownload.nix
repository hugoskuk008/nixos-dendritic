{ ... }:
{
  flake.modules.nixos.server-download-stack = { config, pkgs, ... }:
  let
    netName   = "servarrnetwork";
    netSubnet = "172.39.0.0/24";
    netUnit   = "docker-servarrnetwork";
    vpnPort   = "38940";

    commonEnv = { PUID = "1000"; PGID = "1000"; TZ = "Etc/UTC"; };
    gluetunNs = [ "--network=container:gluetun" ];
  in
  {
    # ---- route registration ----
    myProxy.vhosts = {
      "qbittorrent.internal.example.com" = "localhost:8080";
      "prowlarr.internal.example.com"    = "localhost:9696";
      "nzbget.internal.example.com"      = "localhost:6789";
    };

    # ---- containers ----
    virtualisation.docker.enable = true;
    virtualisation.oci-containers.backend = "docker";

    sops.templates."gluetun.env".content = ''
      VPN_SERVICE_PROVIDER=airvpn
      VPN_TYPE=wireguard
      WIREGUARD_PUBLIC_KEY_SECRETFILE=${config.sops.secrets."arrstack-airvpn-pub".path}
      WIREGUARD_PRESHARED_KEY_SECRETFILE=${config.sops.secrets."arrstack-airvpn-psk".path}
      WIREGUARD_PRIVATE_KEY_SECRETFILE=${config.sops.secrets."arrstack-airvpn-priv".path}
      FIREWALL_VPN_INPUT_PORTS=${vpnPort}
    '';

    sops.templates."qbittorrent.env".content = ''
      TORRENTING_PORT=${vpnPort}
    '';

    systemd.tmpfiles.rules = [
      "d /docker/gluetun    0750 root root - -"
      "d /docker/qbittorrent 0750 root root - -"
      "d /docker/nzbget      0750 root root - -"
      "d /docker/prowlarr    0750 root root - -"
    ];

    systemd.services.${netUnit} = {
      wantedBy = [ "multi-user.target" ];
      before   = [ "docker-gluetun.service" ];
      path     = [ pkgs.docker ];
      serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
      script = ''
        docker network inspect ${netName} >/dev/null 2>&1 ||
          docker network create --driver bridge --subnet ${netSubnet} ${netName}
      '';
    };

    systemd.services.docker-gluetun = {
      requires = [ "${netUnit}.service" ];
      after    = [ "${netUnit}.service" ];
    };

    virtualisation.oci-containers.containers = {
      gluetun = {
        image = "qmcgaw/gluetun:latest";
        autoStart = true;
        ports = [
          "5010:5010"   # qbt
          "8080:8080"   # qbt WebUI
          "6881:6881"   # qbt torrent
          "6789:6789"   # nzbget WebUI
          "9696:9696"   # prowlarr WebUI
          "8191:8191"   # flaresolverr (if added)
        ];
        volumes = [
          "/docker/gluetun:/gluetun"
          "/dev/net/tun:/dev/net/tun"
        ];
        environmentFiles = [ config.sops.templates."gluetun.env".path ];
        capabilities = [ "NET_ADMIN" ];
        devices = [ "/dev/net/tun:/dev/net/tun" ];
        extraOptions = [ "--network=${netName}" ];
      };

      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:latest";
        autoStart = true;
        dependsOn = [ "gluetun" ];
        environment = commonEnv // { WEBUI_PORT = "8080"; };
        environmentFiles = [ config.sops.templates."qbittorrent.env".path ];
        volumes = [
          "/docker/qbittorrent:/config"
          "/data:/data"
        ];
        extraOptions = gluetunNs;
      };

      nzbget = {
        image = "lscr.io/linuxserver/nzbget:latest";
        autoStart = true;
        dependsOn = [ "gluetun" ];
        environment = commonEnv;
        volumes = [
          "/docker/nzbget:/config"
          "/data:/data"
        ];
        extraOptions = gluetunNs;
      };

      prowlarr = {
        image = "lscr.io/linuxserver/prowlarr:latest";
        autoStart = true;
        dependsOn = [ "gluetun" ];
        environment = commonEnv;
        volumes = [ "/docker/prowlarr:/config" ];
        extraOptions = gluetunNs;
      };
    };

    networking.firewall.allowedTCPPorts = [ 5010 8080 6789 9696 8191 ];
    networking.firewall.allowedUDPPorts = [ 6881 ];
  };
}
