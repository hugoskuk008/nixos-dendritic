{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-sonarr = { ... }:
    let
      port = 8989;
    in
    {
      homelab.services.sonarr = {
        inherit port;
        authBypassLocations = [
          "^~ /api/v3/"
          "^~ /api/v5/"
        ];
      };

      imports = [
        (mkServerContainer {
          name = "sonarr";
          image = "lscr.io/linuxserver/sonarr:latest";
          inherit port;
          dockerAssertionMessage = "server-sonarr needs the docker module enabled on this host.";
          missingAddressMessage = "server-sonarr needs homelab.adress set on this host";
          oci = {
            environment = {
              PUID = "1000";
              PGID = "1000";
              TZ = "Europe/Stockholm";
            };
            volumes = [
              "/docker/sonarr:/config"
              "/data:/data"
            ];
          };
        })
      ];
    };
}
