# Per-host registry of the services a host runs.
#
# Service modules register themselves (`homelab.services.<name>.port = ...`). Which host
# a service lives on is simply which host enables that module in its modules.json.
# The ingress module reads these registrations from every host in the flake.
{ ... }:
{
  flake.modules.nixos.homelab-registry = { config, lib, ... }: {
    options.homelab = {
      domain = lib.mkOption {
        type = lib.types.str;
        default = "hogcloud.local";
        description = "Base domain. Services are published as <name>.<domain>.";
      };

      address = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "192.168.1.10";
        description = "This host's LAN IP, which the ingress uses to reach its services.";
      };

      services = lib.mkOption {
        default = { };
        description = "HTTP(S) services on this host that the ingress should publish.";
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            port = lib.mkOption {
              type = lib.types.port;
              description = "Port on this host's address that serves the service.";
            };

            scheme = lib.mkOption {
              type = lib.types.enum [ "http" "https" ];
              default = "http";
              description = ''
                How the ingress talks to the service. "https" assumes a self-signed
                backend certificate, so the ingress encrypts but does not verify it.
              '';
            };

            perHost = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                For services that run on many hosts (Cockpit, exporters, ...).
                Published as <name>-<hostName> instead of <name>, so each host's
                instance gets its own name and the duplicate check stays valid.
              '';
            };
          };
        });
      };
    };

    config.assertions = [
      {
        assertion = config.homelab.services == { } || config.homelab.address != null;
        message = "homelab.services is set on this host but homelab.address is not.";
      }
    ];
  };
}
