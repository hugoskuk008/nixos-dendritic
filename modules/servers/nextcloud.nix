{ ... }:
{
  flake.modules.nixos.server-nextcloud = { config, pkgs, ... }:
    let
      addr =
        if config.homelab.address == null
        then throw "server-nextcloud needs homelab.address set on this host"
        else config.homelab.address;

      domain = "nextcloud.${config.homelab.domain}";
      port = 8081;
      root = "/nextcloud";
      network = "nextcloud";

      envFile = config.sops.secrets."nextcloud/env".path;
      image = "nextcloud:32-apache";

      storage = [
        "${root}/html:/var/www/html"
        "${root}/data:/var/www/html/data"
      ];

    in
    {
      assertions = [
        {
          assertion = config.virtualisation.docker.enable;
          message = "server-nextcloud needs Docker enabled.";
        }
      ];
      virtualisation.oci-containers.backend = "docker";

      homelab.services.nextcloud = {
  inherit port;
  auth = "authentik";

  authBypassLocations = [
    # WebDAV (files, calendars, contacts)
    "~ ^/remote[.]php/(dav|webdav)(/|$)"


    # Native application login flow v2
    "= /index.php/login/v2"
    "= /login/v2"
    "= /login/v2/poll"

  ];
};
  services.nginx.virtualHosts.${domain} = {
        extraConfig = ''
          client_max_body_size 10G;
        '';

        locations."/".extraConfig = ''
          proxy_request_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        '';
      };

      # SOPS decrypts the environment file at activation.
      sops.secrets."nextcloud/env" = {
        mode = "0400";
      };

      # Private Docker network.
      systemd.services.docker-nextcloud-network = {
        description = "Create Nextcloud Docker network";
        wantedBy = [ "multi-user.target" ];
        requires = [ "docker.service" ];
        after = [ "docker.service" ];

        before = [
          "docker-nextcloud-db.service"
          "docker-nextcloud-redis.service"
          "docker-nextcloud.service"
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
        nextcloud-db = {
          image = "postgres:16-alpine";
          autoStart = true;

          environmentFiles = [ envFile ];

          environment = {
            POSTGRES_DB = "nextcloud";
            POSTGRES_USER = "nextcloud";
            PGDATA = "/var/lib/postgresql/data/pgdata";
          };

          volumes = [
            "${root}/postgres:/var/lib/postgresql/data"
          ];

          extraOptions = [ "--network=${network}" ];
        };

        nextcloud-redis = {
          image = "redis:7-alpine";
          autoStart = true;

          cmd = [
            "redis-server"
            "--appendonly"
            "yes"
          ];

          volumes = [
            "${root}/redis:/data"
          ];

          extraOptions = [ "--network=${network}" ];
        };

        nextcloud = {
          inherit image;
          autoStart = true;

          dependsOn = [
            "nextcloud-db"
            "nextcloud-redis"
          ];

          ports = [
            "${addr}:${toString port}:80/tcp"
          ];

          environmentFiles = [ envFile ];

          environment = {
            POSTGRES_HOST = "nextcloud-db";
            POSTGRES_DB = "nextcloud";
            POSTGRES_USER = "nextcloud";

            REDIS_HOST = "nextcloud-redis";

            NEXTCLOUD_ADMIN_USER = "admin";
            NEXTCLOUD_TRUSTED_DOMAINS = domain;

            OVERWRITEHOST = domain;
            OVERWRITEPROTOCOL = "https";
            OVERWRITECLIURL = "https://${domain}";

            PHP_MEMORY_LIMIT = "1024M";
            PHP_UPLOAD_LIMIT = "10G";
          };

          volumes = storage;

          extraOptions = [ "--network=${network}" ];
        };


      };

systemd.services = {
  docker-nextcloud = {
    requires = [ "nextcloud.mount" ];
    after = [ "nextcloud.mount" ];
  };

  docker-nextcloud-db = {
    requires = [ "nextcloud.mount" ];
    after = [ "nextcloud.mount" ];
  };

  docker-nextcloud-redis = {
    requires = [ "nextcloud.mount" ];
    after = [ "nextcloud.mount" ];
  };


};
    };
}

