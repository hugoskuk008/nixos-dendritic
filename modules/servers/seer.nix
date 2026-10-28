{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-seerr = { ... }:
    let
      port = 5055;
    in
    {
      homelab.services.seerr = {
        inherit port;
        authBypassLocations = [
          "^~ /api/v1/"
        ];
      };

      imports = [
        (mkServerContainer {
          name = "seerr";
          image = "ghcr.io/seerr-team/seerr:latest";
          inherit port;
          containerName = "seer";
          dockerAssertionMessage = "server-radarr needs the docker module enabled on this host.";
          missingAddressMessage = "server-seerr needs homelab.address set on this host";
          oci = {
            environment = {
              PUID = "1000";
              PGID = "1000";
              TZ = "Europe/Stockholm";
            };
            volumes = [
              "/docker/seerr:/app/config"
            ];
          };
        })
      ];
    };
}
