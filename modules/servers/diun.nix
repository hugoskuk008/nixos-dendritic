
{ ... }:
{
  flake.modules.nixos.server-diun =
    { config, ... }:
    let
      ntfyToken =
        config.sops.secrets."diun/ntfy-token".path;
    in
    {
      assertions = [
        {
          assertion = config.virtualisation.docker.enable;
          message = "server-diun requires Docker enabled.";
        }
      ];

      virtualisation.oci-containers.backend = "docker";

      # ntfy access token stored using SOPS.
      sops.secrets."diun/ntfy-token" = {
        mode = "0400";
      };

      virtualisation.oci-containers.containers.diun = {
        image = "crazymax/diun:latest";
        autoStart = true;

        cmd = [ "serve" ];

        environment = {
          TZ = "Europe/Stockholm";
          LOG_LEVEL = "info";

          # Persistent database
          DIUN_DB_PATH = "/data/diun.db";

          # Check images every 6 hours
          DIUN_WATCH_SCHEDULE = "0 */6 * * *";
          DIUN_WATCH_JITTER = "30s";
          DIUN_WATCH_WORKERS = "10";
          DIUN_WATCH_FIRSTCHECKNOTIF = "false";

          # Monitor all running Docker containers
          DIUN_PROVIDERS_DOCKER = "true";
          DIUN_PROVIDERS_DOCKER_WATCHBYDEFAULT = "true";

          # Self-hosted ntfy
          DIUN_NOTIF_NTFY_ENDPOINT =
            "https://ntfy.${config.homelab.domain}";

          DIUN_NOTIF_NTFY_TOPIC = "updates";
          DIUN_NOTIF_NTFY_TOKENFILE =
            "/run/secrets/ntfy-token";

          DIUN_NOTIF_NTFY_PRIORITY = "3";
          DIUN_NOTIF_NTFY_TAGS = "whale";
          DIUN_NOTIF_NTFY_TIMEOUT = "10s";
        };

        volumes = [
          "/docker/diun:/data"

          # Docker API for discovering containers
          "/var/run/docker.sock:/var/run/docker.sock:ro"

          # Token is not exposed as an environment value
          "${ntfyToken}:/run/secrets/ntfy-token:ro"
        ];

        extraOptions = [
          "--security-opt=no-new-privileges"
        ];
      };

      # Wait for the ZFS-backed /docker bind mount.
      systemd.services.docker-diun = {
        requires = [ "docker.mount" ];
        after = [ "docker.mount" ];
      };
    };
}

