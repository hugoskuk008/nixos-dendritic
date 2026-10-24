# dnsmasq: answers *.<homelab.domain> with the ingress address, forwards everything else.
# Enable on one always-on host. By default it assumes it runs on the ingress host;
# set homelab.dns.ingressAddress if the resolver lives elsewhere.
{ ... }:
{
  flake.modules.nixos.homelab-dns = { config, lib, internetInterface, ... }:
    let
      cfg = config.homelab;
    in
    {
      options.homelab.dns.ingressAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = cfg.address;
        defaultText = lib.literalExpression "config.homelab.address";
        description = "IP that *.<domain> resolves to (the ingress host's LAN IP).";
      };

      config = {
        assertions = [{
          assertion = cfg.dns.ingressAddress != null;
          message = "homelab-dns needs homelab.address (or homelab.dns.ingressAddress) set.";
        }];

        services.dnsmasq = {
          enable = true;
          resolveLocalQueries = false;   # leave this host's own resolver config alone
          settings = {
            address = "/${cfg.domain}/${cfg.dns.ingressAddress}";

            # Forward everything else; don't read /etc/resolv.conf.
            no-resolv = true;
            server = [ "1.1.1.1" "9.9.9.9" ];

            # Bind per-address so this coexists with systemd-resolved's stub on 127.0.0.53.
            interface = [ internetInterface "tailscale0" ];
            bind-dynamic = true;

            domain-needed = true;
            bogus-priv = true;
            cache-size = 1000;
          };
        };

        # LAN is not a trusted interface; tailscale0 already is (see tailscale.nix).
        networking.firewall.interfaces.${internetInterface} = {
          allowedUDPPorts = [ 53 ];
          allowedTCPPorts = [ 53 ];
        };
      };
    };
}
