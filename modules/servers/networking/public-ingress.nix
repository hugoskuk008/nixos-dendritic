
# Public reverse proxy over the Oracle -> home WireGuard link.
# Independent from the private Authentik proxy.
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
            inherit (svc) port scheme;
            publicEnabled = svc.public.enable or false;

            address =
              if sys.config.homelab.address == null
              then throw "host '${hostName}' registers services without homelab.address"
              else sys.config.homelab.address;
          })
          sys.config.homelab.services))
    flake.nixosConfigurations);

  byName = lib.groupBy (r: r.name) registrations;
  duplicates = lib.filterAttrs (_: rs: lib.length rs > 1) byName;
  allServices = lib.mapAttrs (_: rs: lib.head rs) byName;
  publicServices =
    lib.filterAttrs (_: svc: svc.publicEnabled) allServices;

in
{
  flake.modules.nixos.public-ingress = { config, lib, ... }:
    let
      cfg = config.homelab.ingress.public;

      listener = [{
        addr = cfg.listenAddress;
        port = cfg.listenPort;
        ssl = false;
      }];

      mkPublicVhost = name: svc: {
        listen = listener;

        locations."/" = {
          proxyPass =
            "${svc.scheme}://${svc.address}:${toString svc.port}";
          proxyWebsockets = true;
          recommendedProxySettings = false;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_set_header X-Real-IP $remote_addr;

            # Strip client-supplied Authentik identity headers.
            proxy_set_header X-Authentik-Username "";
            proxy_set_header X-Authentik-Groups "";
            proxy_set_header X-Authentik-Email "";
            proxy_set_header X-Authentik-Name "";
            proxy_set_header X-Authentik-Uid "";
            proxy_set_header X-Authentik-Entitlements "";
          '' + lib.optionalString (svc.scheme == "https") ''
            proxy_ssl_verify off;
          '';
        };
      };

      denyVhost = {
        serverName = "_";

        listen = lib.mkForce [{
          addr = cfg.listenAddress;
          port = cfg.listenPort;
          ssl = false;
          extraParameters = [ "default_server" ];
        }];

        locations."/".return = "444";
      };

    in
    {
      options.homelab.ingress.public = {
        enable = lib.mkEnableOption
          "a WireGuard-only public HTTP ingress";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "hogcloud.bid";
        };

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "10.77.0.2";
        };

        listenPort = lib.mkOption {
          type = lib.types.port;
          default = 8443;
        };

        wireguardInterface = lib.mkOption {
          type = lib.types.str;
          default = "wg-oracle";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = duplicates == { };
            message =
              "Public ingress requires unique service names across hosts.";
          }
          {
            assertion =
              builtins.hasAttr cfg.wireguardInterface
                config.networking.wireguard.interfaces;
            message =
              "Public ingress requires the configured WireGuard interface.";
          }
          {
            assertion = cfg.listenAddress != "0.0.0.0";
            message =
              "Public ingress must not listen on all IPv4 interfaces.";
          }
          {
            assertion = cfg.domain != config.homelab.domain;
            message =
              "Public ingress domain must differ from the private domain.";
          }
        ];

        services.nginx.enable = true;

        services.nginx.virtualHosts = {
          "oracle-edge-default" = denyVhost;

          # Disable the previous temporary test endpoint.
          "edge-test.hogcloud.bid" = {
            listen = lib.mkForce listener;
            locations."/".return = lib.mkForce "444";
          };
        } // lib.mapAttrs'
          (name: svc:
            lib.nameValuePair
              "${name}.${cfg.domain}"
              (mkPublicVhost name svc))
          publicServices;

        # Nginx must bind after the WireGuard IP exists.
        systemd.services.nginx = {
          requires = [
            "wireguard-${cfg.wireguardInterface}.service"
          ];
          after = [
            "wireguard-${cfg.wireguardInterface}.service"
          ];
        };
      };
    };
}

