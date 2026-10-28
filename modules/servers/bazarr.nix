{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-bazarr = { ... }:
    let
      port = 6767;
    in
    {
      homelab.services.bazarr = {
        inherit port;
        authBypassLocations = [
          "^~ /api/"
        ];
      };

      imports = [
        (mkServerContainer {
          name = "bazarr";
          image = "lscr.io/linuxserver/bazarr:latest";
          inherit port;
          dockerAssertionMessage = "server-bazarr needs the docker module enabled on this host.";
          missingAddressMessage = "server-bazarr needs homelab.adress set on this host";
          oci = {
            environment = {
              PUID = "1000";
              PGID = "1000";
              TZ = "Europe/Stockholm";
            };
            volumes = [
              "/docker/bazarr:/config"
              "/data:/data"
            ];
          };
        })
      ];
    };
}
