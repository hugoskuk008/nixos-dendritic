
{ ... }:
{
  flake.modules.nixos.authentik = { config, lib, pkgs, ... }:
    let
      envFile = config.sops.secrets."authentik/env".path;
      network = "authentik";
      image = "ghcr.io/goauthentik/server:2026.8.3";
    in
    {
      assertions = [
        {
          assertion = config.virtualisation.docker.enable;
          message = "authentik requires Docker to be enabled.";
        }
      ];

      sops.secrets."authentik/env" = {
        mode = "0400";
      };
      services.nginx.virtualHosts."auth.home.hogcloud.bid" = {
  forceSSL = true;
  useACMEHost = "home.hogcloud.bid";

  locations."/" = {
    proxyPass = "http://127.0.0.1:9000";

    proxyWebsockets = true;

    extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        '';
       };
     };
      virtualisation.oci-containers.backend = "docker";


      # Create an isolated Docker network for Authentik and its database.
      systemd.services.docker-authentik-network = {
        description = "Create Authentik Docker network";
        wantedBy = [ "multi-user.target" ];
        requires = [ "docker.service" ];
        after = [ "docker.service" ];
        before = [
          "docker-authentik-db.service"
          "docker-authentik-server.service"
          "docker-authentik-worker.service"
        ];
        path = [ pkgs.docker ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };

        script = ''
          docker network inspect ${network} >/dev/null 2>&1 ||
            docker network create --driver bridge ${network}
        '';
      };

      virtualisation.oci-containers.containers = {
        authentik-db = {
          image = "postgres:16-alpine";
          autoStart = true;
          environmentFiles = [ envFile ];
          volumes = [
            "/docker/authentik/postgres:/var/lib/postgresql/data"
          ];
          extraOptions = [ "--network=${network}" ];
        };

        authentik-server = {
          inherit image;
          cmd = [ "server" ];
          autoStart = true;
          dependsOn = [ "authentik-db" ];
          environmentFiles = [ envFile ];
          ports = [
            "127.0.0.1:9000:9000"
          ];
          volumes = [
            "/docker/authentik/custom-templates:/templates"
          ];
          extraOptions = [ "--network=${network}" ];
        };

        authentik-worker = {
          inherit image;
          cmd = [ "worker" ];
          autoStart = true;
          dependsOn = [ "authentik-db" ];
          environmentFiles = [ envFile ];
          volumes = [
            "/docker/authentik/custom-templates:/templates"
          ];
          extraOptions = [ "--network=${network}" ];
        };
      };

      # Ensure the network exists before each container starts.
      systemd.services.docker-authentik-db = {
        requires = [ "docker-authentik-network.service" ];
        after = [ "docker-authentik-network.service" ];
      };

      systemd.services.docker-authentik-server = {
        requires = [ "docker-authentik-network.service" ];
        after = [ "docker-authentik-network.service" ];
      };

      systemd.services.docker-authentik-worker = {
        requires = [ "docker-authentik-network.service" ];
        after = [ "docker-authentik-network.service" ];
      };
    };
}

