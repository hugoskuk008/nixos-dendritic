{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-radarr = { ... }:
    let
      port = 7878;
    in
    {
      homelab.services.radarr = {
        inherit port;
        authBypassLocations = [
          "^~ /api/v3/"
        ];
      };

      imports = [
        (mkServerContainer {
          name = "radarr";
          image = "lscr.io/linuxserver/radarr:latest";
          inherit port;
          dockerAssertionMessage = "server-radarr needs the docker module enabled on this host.";
          missingAddressMessage = "server-radarr needs homelab.address set on this host";
          oci = {
            environment = {
              PUID = "1000";
              PGID = "1000";
              TZ = "Europe/Stockholm";
            };
            volumes = [
              "/docker/radarr:/config"
              "/data:/data"
            ];
          };
        })
      ];
    };
}
