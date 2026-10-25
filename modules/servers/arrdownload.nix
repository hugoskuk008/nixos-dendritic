{ ... }:
{
  flake.modules.nixos.server-download-stack = { config, lib, pkgs, ... }:
  let
    addr =
      if config.homelab.address == null
      then throw "server-download-stack needs homelab.address set on this host"
      else config.homelab.address;
       reach = [ "sonarr" "radarr" "seerr" ];
    hostEntries = map
      (n: "--add-host=${n}.${config.homelab.domain}:${config.homelab.ingressAddress}")
      reach;
    appdata = "/docker";

    webPorts = { qbittorrent = 8080; mousehole = 5010; prowlarr = 9696; nzbget = 6789; };

    netName   = "servarrnetwork";
    netSubnet = "172.39.0.0/24";
    netUnit   = "docker-servarrnetwork";
    vpnPort   = "38940";

    commonEnv = { PUID = "1000"; PGID = "1000"; TZ = "Europe/Stockholm"; };
    gluetunNs = [ "--network=container:gluetun" ];

    privKey = config.sops.secrets."airvpn/wg-privateKey".path;
    pskKey  = config.sops.secrets."airvpn/wg-presharedKey".path;
  in
  {
    assertions = [{
      assertion = config.virtualisation.docker.enable;
      message = "server-download-stack needs the docker module enabled on this host.";
    }];
    virtualisation.oci-containers.backend = "docker";
    # ---- publish the WebUIs through the ingress ----
    homelab.services = lib.mapAttrs (_: port: { inherit port; }) webPorts;

    # ---- secrets ----
    sops.secrets."airvpn/wg-privateKey"   = { mode = "0400"; };
    sops.secrets."airvpn/wg-presharedKey" = { mode = "0400"; };

    systemd.tmpfiles.rules = [
      "d ${appdata}/gluetun     0750 root root - -"
      "d ${appdata}/qbittorrent 0750 root root - -"
      "d ${appdata}/nzbget      0750 root root - -"
      "d ${appdata}/prowlarr    0750 root root - -"
    ];

    # ---- shared network ----
    systemd.services.${netUnit} = {
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      after    = [ "docker.service" ];
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

    # ---- containers ----
    virtualisation.oci-containers.containers = {
      gluetun = {
        image = "qmcgaw/gluetun:latest";
        autoStart = true;
        ports = lib.mapAttrsToList
          (_: p: "${addr}:${toString p}:${toString p}")
          webPorts;
        volumes = [
          "${appdata}/gluetun:/gluetun"
          "/dev/net/tun:/dev/net/tun"
          "${privKey}:/run/secrets/wireguard_private_key:ro"
          "${pskKey}:/run/secrets/wireguard_preshared_key:ro"
        ];
        environment = {
          VPN_SERVICE_PROVIDER = "airvpn";
          VPN_TYPE = "wireguard";
          WIREGUARD_PRIVATE_KEY_SECRETFILE = "/run/secrets/wireguard_private_key";
          WIREGUARD_PRESHARED_KEY_SECRETFILE = "/run/secrets/wireguard_preshared_key";
          WIREGUARD_ADDRESSES      = "10.174.25.121/32";
          SERVER_COUNTRIES         = "Netherlands";
          FIREWALL_VPN_INPUT_PORTS = vpnPort;
          FIREWALL_OUTBOUND_SUBNETS = "192.168.10.0/24,172.39.0.0/24";
        };
        capabilities = { NET_ADMIN = true; };
        devices = [ "/dev/net/tun:/dev/net/tun" ];
       extraOptions = [ "--network=${netName}" ] ++ hostEntries;     
       };

      qbittorrent = {
        image = "lscr.io/linuxserver/qbittorrent:5.2.4_v2.0.15-ls481";
        autoStart = true;
        dependsOn = [ "gluetun" ];
        environment = commonEnv // {
          WEBUI_PORT = toString webPorts.qbittorrent;
          TORRENTING_PORT = vpnPort;
        };
        volumes = [
          "${appdata}/qbittorrent:/config"
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
          "${appdata}/nzbget:/config"
          "/data:/data"
        ];
        extraOptions = gluetunNs;
      };
      mousehole = {
        image = "tmmrtn/mousehole:latest";
        autoStart = true;
        dependsOn =  ["gluetun"];
        environment = {
          TZ = "Europe/Stockholm";
          MOUSEHOLE_AUTH_PASSWORD = "passw0rd";
          MOUSEHOLE_ALLOWED_HOSTS = "mousehole.home.hogcloud.bid";
          MOUSEHOLE_ALLOWED_ORIGINS = "https://mousehole.home.hogcloud.bid";
        };
        volumes = ["${appdata}/mousehole:/mousehole"];
        extraOptions = gluetunNs;
      };
      prowlarr = {
        image = "lscr.io/linuxserver/prowlarr:latest";
        autoStart = true;
        dependsOn = [ "gluetun" ];
        environment = commonEnv;
        volumes = [ "${appdata}/prowlarr:/config" ];
        extraOptions = gluetunNs;
      };
    };
  };
}
