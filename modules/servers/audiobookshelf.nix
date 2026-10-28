{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-audiobookshelf = { ... }:
    let
      port = 13378;
    in
    {
      homelab.services.audiobookshelf = {
        inherit port;
      };

      imports = [
        (mkServerContainer {
          name = "audiobookshelf";
          image = "ghcr.io/advplyr/audiobookshelf:latest";
          inherit port;
          containerPort = 80;
          dockerAssertionMessage = "server-audiobookshelf needs the docker module enabled on this host.";
          missingAddressMessage = "server-audiobookshelf needs homelab.adress set on this host";
          oci = {
            environment = {
              PUID = "1000";
              PGID = "1000";
              TZ = "Europe/Stockholm";
            };
            volumes = [
              "/docker/audiobookshelf/config:/config"
              "/data/Media/Audiobooks/:/audiobooks"
              "/docker/audiobookshelf/metadata:/metadata"
            ];
          };
        })
      ];
    };
}
