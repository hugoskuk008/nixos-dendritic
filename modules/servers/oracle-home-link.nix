
{ ... }:
{
  flake.modules.nixos.oracle-home-link =
    { config, lib, pkgs, ... }:
    let
      ipt = "${pkgs.iptables}/bin/iptables";

      oracleAddress = "10.77.0.1";
      homeAddress = "10.77.0.2";

      # Dedicated public-ingress listener.
      # Not the existing private port 443.
      ingressPort = 8443;

      chain = "HL_ORACLE_WG";
    in
    {
      networking.wireguard.enable = true;

      networking.wireguard.interfaces.wg-oracle = {
        ips = [ "${homeAddress}/32" ];

        privateKeyFile =
          "/etc/wireguard/oracle-home.key";

        peers = [
          {
            publicKey = "naIdD2/b/JzwAWlULwurr6ynd9r+JOylg9m2DmU+Bns=";

            allowedIPs = [
              "${oracleAddress}/32"
            ];

            endpoint = "82.70.54.97:51820";

            # Home initiates through its router/NAT.
            persistentKeepalive = 25;
          }
        ];
      };

      # Only the dedicated public ingress is reachable
      # through the WireGuard interface.
      networking.firewall.interfaces.wg-oracle.allowedTCPPorts =
        [ ingressPort ];

      # Enforce isolation before Docker/NAT and the
      # normal NixOS INPUT firewall rules.
      networking.firewall.extraCommands = ''
        ${ipt} -w -t raw -N ${chain} 2>/dev/null || true
        ${ipt} -w -t raw -F ${chain}

        # Permit Oracle to contact only the dedicated
        # home ingress address and port.
        ${ipt} -w -t raw -A ${chain} \
          -s ${oracleAddress}/32 \
          -d ${homeAddress}/32 \
          -p tcp --dport ${toString ingressPort} \
          -j RETURN

        # Everything else arriving over this tunnel
        # gets dropped.
        ${ipt} -w -t raw -A ${chain} -j DROP

        ${ipt} -w -t raw -C PREROUTING \
          -i wg-oracle -j ${chain} 2>/dev/null ||
          ${ipt} -w -t raw -I PREROUTING 1 \
            -i wg-oracle -j ${chain}
      '';

      networking.firewall.extraStopCommands = ''
        ${ipt} -w -t raw -D PREROUTING \
          -i wg-oracle -j ${chain} 2>/dev/null || true

        ${ipt} -w -t raw -F ${chain} 2>/dev/null || true
        ${ipt} -w -t raw -X ${chain} 2>/dev/null || true
      '';

      # Temporary test virtual host.
      services.nginx.virtualHosts = {
        # Deny requests with unrecognized Host headers
        # on this dedicated listener.
        "oracle-edge-default" = {
          serverName = "_";

          listen = [
            {
              addr = "10.77.0.2";
              port = ingressPort;
              ssl = false;
              extraParameters = [ "default_server" ];
            }
          ];

          locations."/".return = "444";
        };

        "edge-test.hogcloud.bid" = {
          listen = [
            {
              addr = "10.77.0.2";
              port = ingressPort;
              ssl = false;
            }
          ];

          locations."/".return =
            "200 'Hogcloud home ingress OK'";
        };
      };
    };
}

