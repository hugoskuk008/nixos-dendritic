
{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-ntfy = { config, ... }:
    let
      port = 2586;
    in
    {
      homelab.services.ntfy = {
        inherit port;
        auth = "none";
        public.enable = false;
      };

      imports = [
        (mkServerContainer {
          name = "ntfy";
          image = "binwiederhier/ntfy:latest";

          inherit port;
          containerPort = 80;

          dockerAssertionMessage =
            "server-ntfy requires Docker enabled.";

          missingAddressMessage =
            "server-ntfy requires homelab.address.";

          oci = {
            cmd = [ "serve" ];

            environment = {
              NTFY_BASE_URL =
                "https://ntfy.${config.homelab.domain}";

              NTFY_LISTEN_HTTP = ":80";

              NTFY_CACHE_FILE =
                "/var/lib/ntfy/cache.db";

              NTFY_AUTH_FILE =
                "/var/lib/ntfy/auth.db";

              NTFY_AUTH_DEFAULT_ACCESS = "deny-all";
              NTFY_ENABLE_LOGIN = "true";
              NTFY_ENABLE_SIGNUP = "false";

              NTFY_BEHIND_PROXY = "true";

              NTFY_ATTACHMENT_CACHE_DIR =
                "/var/lib/ntfy/attachments";

              NTFY_CACHE_DURATION = "168h";
            };

            volumes = [
              "/docker/ntfy:/var/lib/ntfy"
            ];
          };
        })
      ];

      systemd.services.docker-ntfy = {
        requires = [ "docker.mount" ];
        after = [ "docker.mount" ];
      };
    };
}

