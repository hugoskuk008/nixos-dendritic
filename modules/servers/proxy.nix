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
            address =
              if sys.config.homelab.address == null
              then throw "host '${hostName}' registers homelab services but has no homelab.address set"
              else sys.config.homelab.address;
          })
          sys.config.homelab.services))
    flake.nixosConfigurations);

  byName = lib.groupBy (r: r.name) registrations;
  duplicates = lib.filterAttrs (_: rs: lib.length rs > 1) byName;
  published = lib.mapAttrs (_: rs: lib.head rs) byName;
in
{
  flake.modules.nixos.proxy = { config, lib, ... }:
    let
      cfg = config.homelab.ingress;
      domain = config.homelab.domain;
      tls = cfg.acme.enable;
      tlsHost = lib.optionalAttrs tls { useACMEHost = domain; forceSSL = true; };
    in
    {
      options.homelab.ingress.acme = {
        enable = lib.mkEnableOption "HTTPS with a wildcard certificate from Let's Encrypt (DNS-01)";
        email = lib.mkOption {
          type = lib.types.str;
          description = "Contact address for Let's Encrypt.";
        };
        dnsProvider = lib.mkOption {
          type = lib.types.str;
          default = "cloudflare";
          description = "lego DNS provider code.";
        };
        credentialFiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.path;
          default = { };
          description = "lego credential variables (e.g. CLOUDFLARE_DNS_API_TOKEN_FILE) to file paths.";
        };
        staging = lib.mkEnableOption "the Let's Encrypt staging CA (use while testing; certs are untrusted)";
      };

      config = lib.mkMerge [
        {
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
            recommendedTlsSettings = true;

            virtualHosts = {
              # Anything that doesn't match a published name.
              "_" = {
                default = true;
                locations."/".return = "404";
              } // tlsHost;
            } // lib.mapAttrs'
              (name: s: lib.nameValuePair "${name}.${domain}" ({
                locations."/" = {
                  proxyPass = "${s.scheme}://${s.address}:${toString s.port}";
                  proxyWebsockets = true;
                  extraConfig = lib.optionalString (s.scheme == "https") ''
                    proxy_ssl_verify off;
                  '';
                };
              } // tlsHost))
              published;
          };

          networking.firewall.allowedTCPPorts = [ 80 53 ];
        }

        (lib.mkIf tls {
          security.acme = {
            acceptTerms = true;
            defaults.email = cfg.acme.email;
            certs.${domain} = {
              domain = "*.${domain}";
              dnsProvider = cfg.acme.dnsProvider;
              credentialFiles = cfg.acme.credentialFiles;
              # Don't resolve through our own dnsmasq, which answers for this domain.
              dnsResolver = "1.1.1.1:53";
              group = config.services.nginx.group;
              server = lib.mkIf cfg.acme.staging
                "https://acme-staging-v02.api.letsencrypt.org/directory";
            };
          };

          networking.firewall.allowedTCPPorts = [ 443 ];
        })
      ];
    };
}
