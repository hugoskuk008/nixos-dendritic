{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-jellyfin = { ... }:
    let
      port = 8096;
    in
    {
      homelab.services.jellyfin = {
        inherit port;
        auth = "none";
        public.enable = true;
      };

      imports = [
        (mkServerContainer {
          name = "jellyfin";
          image = "jellyfin/jellyfin:latest";
          inherit port;
          portSuffix = "/tcp";
          dockerAssertionMessage = "server-jellyfin needs the Docker module enabled on this host.";
          missingAddressMessage = "server-jellyfin needs homelab.address set on this host";
          oci = {
            user = "1000:1000";
            volumes = [
              "/docker/jellyfin/config:/config"
              "/docker/jellyfin/cache:/cache"
              "/data/Media/:/media:ro"
            ];
            ports = [
              "7359:7359/udp"
            ];
            extraOptions = [
              "--device=nvidia.com/gpu=all"
            ];
          };
        })
      ];
    };
}
