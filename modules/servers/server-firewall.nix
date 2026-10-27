#this is not an actual firewall it just restricts the services running on this host to proxy only, it is an extention for the firewall module


{ ... }:
{
  flake.modules.nixos.server-backend-isolation =
    { config, lib, pkgs, ... }:
    let
      cfg = config.homelab;

      chain = "HL_PROXY_ONLY";

      ipt = "${pkgs.iptables}/bin/iptables";
      ip6t = "${pkgs.iptables}/bin/ip6tables";

      # Automatically derive backend ports from this host.
      ports = lib.unique (
        map (svc: svc.port)
          (lib.attrValues cfg.services)
      );

      # IPv4: only the ingress host may connect to
      # published backend ports on this host's LAN IP.
      ipv4Rules = lib.concatMapStringsSep "\n"
        (port: ''
          ${ipt} -w -t raw -A ${chain} \
            -d ${cfg.address}/32 \
            -p tcp --dport ${toString port} \
            ! -s ${cfg.ingressAddress}/32 \
            -j DROP
        '')
        ports;

      # The registry uses IPv4 backend addresses.
      # Deny direct external IPv6 access to these ports.
      ipv6Rules = lib.concatMapStringsSep "\n"
        (port: ''
          ${ip6t} -w -t raw -A ${chain} \
            -p tcp --dport ${toString port} \
            -j DROP
        '')
        ports;

    in
    {
      assertions = [
        {
          assertion =
            ports == [ ] || (
              cfg.address != null &&
              cfg.ingressAddress != null
            );

          message = ''
            backend-isolation requires homelab.address
            and homelab.ingressAddress on service hosts.
          '';
        }
        {
          assertion =
            config.networking.firewall.enable &&
            config.networking.firewall.backend == "iptables";

          message = ''
            backend-isolation requires the enabled
            iptables firewall backend.
          '';
        }
      ];

      networking.firewall = {
        extraCommands = ''
          # Create our private chain if it doesn't exist.
          ${ipt} -w -t raw -N ${chain} 2>/dev/null || true

          # Refresh rules on every firewall activation.
          ${ipt} -w -t raw -F ${chain}

          ${ipv4Rules}

          # Attach before Docker's NAT processing.
          ${ipt} -w -t raw -C PREROUTING \
            -j ${chain} 2>/dev/null ||
            ${ipt} -w -t raw -I PREROUTING 1 \
              -j ${chain}
        '' + lib.optionalString config.networking.enableIPv6 ''
          ${ip6t} -w -t raw -N ${chain} 2>/dev/null || true
          ${ip6t} -w -t raw -F ${chain}

          ${ipv6Rules}

          ${ip6t} -w -t raw -C PREROUTING \
            -j ${chain} 2>/dev/null ||
            ${ip6t} -w -t raw -I PREROUTING 1 \
              -j ${chain}
        '';

        extraStopCommands = ''
          ${ipt} -w -t raw -D PREROUTING \
            -j ${chain} 2>/dev/null || true

          ${ipt} -w -t raw -F ${chain} 2>/dev/null || true
          ${ipt} -w -t raw -X ${chain} 2>/dev/null || true
        '' + lib.optionalString config.networking.enableIPv6 ''
          ${ip6t} -w -t raw -D PREROUTING \
            -j ${chain} 2>/dev/null || true

          ${ip6t} -w -t raw -F ${chain} 2>/dev/null || true
          ${ip6t} -w -t raw -X ${chain} 2>/dev/null || true
        '';
      };
    };
}

