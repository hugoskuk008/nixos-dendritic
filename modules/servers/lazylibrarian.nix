{ ... }:
let
  mkServerContainer = import ./_lib/mk-server-container.nix;
in
{
  flake.modules.nixos.server-lazyLibrarian = { ... }:
    let
      port = 5299;
    in
    {
      homelab.services.lazyLibrarian = {
        inherit port;
      };

      imports = [
        (mkServerContainer {
          name = "lazyLibrarian";
          image = "lscr.io/linuxserver/lazylibrarian:latest";
          inherit port;
          dockerAssertionMessage = "server-bazarr needs the docker module enabled on this host.";
          missingAddressMessage = "server-lazyLibrarian needs homelab.adress set on this host";
          oci = {
            environment = {
              PUID = "1000";
              PGID = "1000";
              TZ = "Europe/Stockholm";
            };
            volumes = [
              "/docker/lazylibrarian:/config"
              "/data:/data"
            ];
          };
        })
      ];
    };
}
