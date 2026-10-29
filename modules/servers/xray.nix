# NAS-local Xray endpoint. All public ingress remains Cloudflare -> Oracle -> WG -> Nginx.
{ ... }:
{
  flake.modules.nixos.server-xray = { config, lib, ... }:
    let
      port = 10000;
    in
    {
      assertions = [
        {
          assertion = config.homelab.address == "192.168.10.10";
          message = "server-xray expects the NAS backend IP 192.168.10.10";
        }
      ];

      # The public ingress forwards WebSockets to xray.hogcloud.bid.
      # The private xray.home.hogcloud.bid host remains Authentik-protected.
      homelab.services.xray = {
        inherit port;
        auth = "authentik";
        public.enable = true;
      };

      # Only two scalar secrets are needed. They are already supported by
      # the repository's SOPS store at secrets/secrets.json.
      sops.secrets."xray/uuid" = {
        mode = "0400";
        restartUnits = [ "xray.service" ];
      };
      sops.secrets."xray/decryption" = {
        mode = "0400";
        restartUnits = [ "xray.service" ];
      };

      # Construct public Xray settings at evaluation time, but substitute
      # secret values only during activation (never into /nix/store).
      sops.templates."xray-config.json".content = builtins.toJSON {
        log = {
          access = "none";
          loglevel = "warning";
        };
        inbounds = [
          {
            listen = config.homelab.address;
            inherit port;
            protocol = "vless";
            settings = {
              decryption = config.sops.placeholder."xray/decryption";
              users = [
                { id = config.sops.placeholder."xray/uuid"; }
              ];
            };
            streamSettings = {
              method = "websocket";
              security = "none";
              wsSettings.path = "/xray-vless";
            };
          }
        ];
        outbounds = [ { protocol = "freedom"; } ];
      };

      # The pinned nixpkgs Xray unit uses DynamicUser and LoadCredential.
      services.xray = {
        enable = true;
        settingsFile = config.sops.templates."xray-config.json".path;
      };

      systemd.services.xray = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          CapabilityBoundingSet = lib.mkForce "";
          AmbientCapabilities = lib.mkForce "";
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectControlGroups = true;
        };
      };
    };
}
