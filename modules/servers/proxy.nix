# Reverse proxy that publishes every service registered on any host in the flake.
# Enable this module on exactly one host (the one the wildcard DNS record points at).
{ config, lib, ... }:
let
  flake = config.flake;

  # [ { name; hostName; address; port; scheme; } ... ] across every host that uses the registry.
  registrations = lib.concatLists (lib.mapAttrsToList
    (hostName: sys:
      lib.optionals (sys.options ? homelab)
        (lib.mapAttrsToList
          (name: svc: {
            name = if svc.perHost then "${name}-${hostName}" else name;
            inherit hostName;
            inherit (svc) port scheme;
            address = sys.config.homelab.address;
          })
          sys.config.homelab.services))
    flake.nixosConfigurations);

  byName = lib.groupBy (r: r.name) registrations;
  duplicates = lib.filterAttrs (_: rs: lib.length rs > 1) byName;
  published = lib.mapAttrs (_: rs: lib.head rs) byName;
in
{
  flake.modules.nixos.proxy = { config, lib, ... }: {
    assertions = [
      {
        assertion = duplicates == { };
        message =
          "Services registered on more than one host (disable them on all but one): "
          + lib.concatStringsSep "; " (lib.mapAttrsToList
            (name: rs: "${name} on ${lib.concatMapStringsSep ", " (r: r.hostName) rs}")
            duplicates);
      }
    ];

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts = {
        # Anything that doesn't match a published name.
        "_" = {
          default = true;
          locations."/".return = "404";
        };
      } // lib.mapAttrs'
        (name: s: lib.nameValuePair "${name}.${config.homelab.domain}" {
          locations."/" = {
            proxyPass = "${s.scheme}://${s.address}:${toString s.port}";
            proxyWebsockets = true;
            extraConfig = lib.optionalString (s.scheme == "https") ''
              proxy_ssl_verify off;
            '';
          };
        })
        published;
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}
