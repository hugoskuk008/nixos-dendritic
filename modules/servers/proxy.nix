# Central reverse proxy. Application routing and browser authentication are generated
# from each host's homelab.services registrations.
# Enable on exactly one host (the wildcard DNS target).
{ config, lib, ... }:
let
  flake = config.flake;

  registrations = lib.concatLists (lib.mapAttrsToList
    (hostName: sys:
      lib.optionals (sys.options ? homelab)
        (lib.mapAttrsToList
          (name: svc: {
            name = if svc.perHost then "${name}-${hostName}" else name;
            inherit hostName;
            inherit (svc) port scheme auth;
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
      ak = cfg.authentik;
      authHostname = "auth.${domain}";
      protected = lib.filterAttrs (_: svc: svc.auth == "authentik") published;

      # Checks are internal subrequests to the embedded Authentik outpost.
      # Only the login portal itself has a publicly routable outpost endpoint.
      authentikLocations = {
        "= /_authentik_check" = {
          recommendedProxySettings = false;
          proxyPass = "${ak.upstream}/outpost.goauthentik.io/auth/nginx";
          extraConfig = ''
            internal;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            proxy_set_header Host $host;
            proxy_set_header X-Original-URL $scheme://$host$request_uri;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header Cookie $http_cookie;
            # Reject client-controlled original-URI override (Auth source advisory).
            proxy_set_header X-Original-URI "";
          '';
        };

        "@authentik_signin" = {
          extraConfig = ''
            internal;
            add_header Set-Cookie $authentik_cookie always;
            return 302 https://${authHostname}/outpost.goauthentik.io/start?rd=$scheme://$host$request_uri;
          '';
        };
      };

      mkPublishedVhost = name: svc:
        let requiresAuth = svc.auth == "authentik";
        in {
          locations = {
            "/" = {
              proxyPass = "${svc.scheme}://${svc.address}:${toString svc.port}";
              proxyWebsockets = true;
              extraConfig =
                (lib.optionalString requiresAuth ''
                  auth_request /_authentik_check;
                  error_page 401 = @authentik_signin;
                  auth_request_set $authentik_cookie $upstream_http_set_cookie;
                  add_header Set-Cookie $authentik_cookie always;
                  # We use Authentik as a gate, NOT header-based login at the backend.
                  # Never forward client-forged identity headers to the application.
                  proxy_set_header X-Authentik-Username "";
                  proxy_set_header X-Authentik-Groups "";
                  proxy_set_header X-Authentik-Email "";
                  proxy_set_header X-Authentik-Name "";
                  proxy_set_header X-Authentik-Uid "";
                  proxy_set_header X-Authentik-Entitlements "";
                '')
                + (lib.optionalString (svc.scheme == "https") ''
                  # Existing behaviour; migrate upstreams to verified certificates.
                  proxy_ssl_verify off;
                '');
            };
          } // lib.optionalAttrs requiresAuth authentikLocations;
        } // tlsHost;
    in
    {
      options.homelab.ingress = {
        acme = {
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
            description = "lego credential variables to credential file paths.";
          };
          staging = lib.mkEnableOption "the Let's Encrypt staging CA";
        };

        authentik = {
          enable = lib.mkEnableOption "domain-level Authentik forward authentication";
          upstream = lib.mkOption {
            type = lib.types.str;
            default = "http://127.0.0.1:9000";
            description = "Private URL of the embedded Authentik outpost, reachable by Nginx.";
          };
        };
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
            {
              assertion = protected == { } || ak.enable;
              message = "A service requests Authentik, but homelab.ingress.authentik.enable is false.";
            }
            {
              assertion = !ak.enable || tls;
              message = "Authentik forward auth requires homelab.ingress.acme.enable for HTTPS.";
            }
            {
              assertion = !ak.enable || !(builtins.hasAttr "auth" published);
              message = "Service name 'auth' is reserved for the Authentik login portal.";
            }
          ];

          services.nginx = {
            enable = true;
            recommendedProxySettings = true;
            recommendedOptimisation = true;
            recommendedGzipSettings = true;
            recommendedTlsSettings = true;

            virtualHosts =
              {
                "_" = {
                  default = true;
                  locations."/".return = "404";
                } // tlsHost;
              }
              // lib.mapAttrs' (name: svc:
                lib.nameValuePair "${name}.${domain}" (mkPublishedVhost name svc)) published
              // lib.optionalAttrs ak.enable {
                "${authHostname}" = {
                  locations."/" = {
                    proxyPass = ak.upstream;
                    proxyWebsockets = true;
                  };
                } // tlsHost;
              };
          };

          # Firewall exposure is configured separately by the NAS network policy.
          # In particular, do not open DNS (53) in the reverse proxy module.
        }

        (lib.mkIf tls {
          security.acme = {
            acceptTerms = true;
            defaults.email = cfg.acme.email;
            certs.${domain} = {
              domain = "*.${domain}";
              dnsProvider = cfg.acme.dnsProvider;
              credentialFiles = cfg.acme.credentialFiles;
              dnsResolver = "1.1.1.1:53";
              group = config.services.nginx.group;
              server = lib.mkIf cfg.acme.staging
                "https://acme-staging-v02.api.letsencrypt.org/directory";
            };
          };

        })
      ];
    };
}
