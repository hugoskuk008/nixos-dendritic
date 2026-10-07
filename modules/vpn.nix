{...}:{

flake.modules.nixos.gluetun = {pkgs,secrets,...}: {
 environment.systemPackages = [pkgs.iproute2];
   systemd.services.vpn-netns = {
      description = "Create the VPN network namespace";
      wantedBy = [ "multi-user.target" ];
      before = [ "podman-gluetun.service" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "create-vpn-netns" ''
           set -eu

          IP=${pkgs.iproute2}/bin/ip

          if ! $IP netns list | ${pkgs.gnugrep}/bin/grep -q '^vpn\([[:space:]]\|$\)'; then
            $IP netns add vpn
          fi

          $IP -n vpn link set lo up

          if ! $IP link show vpn-host >/dev/null 2>&1; then
            $IP link add vpn-host type veth peer name vpn-ns
            $IP link set vpn-ns netns vpn
          fi

          $IP addr replace 10.203.0.1/30 dev vpn-host
          $IP link set vpn-host up

          $IP -n vpn addr replace 10.203.0.2/30 dev vpn-ns
          $IP -n vpn link set vpn-ns up
          $IP -n vpn route replace default via 10.203.0.1
        '';
        ExecStop = "${pkgs.iproute2}/bin/ip netns del vpn";
      };
    };
      
      networking.nat = {
        enable = true;
        externalInterface = "wlp99s0"; # Replace with the host's uplink interface.
        internalIPs = [ "10.203.0.2" ];
    };


  systemd.services.podman-gluetun = {
    requires = [ "vpn-netns.service" ];
    after = [ "vpn-netns.service" ];
    bindsTo = [ "vpn-netns.service" ];
    };

  virtualisation.podman.enable = true;
  virtualisation.oci-containers = {
  
      backend = "podman";
      containers = {
        gluetun = {
          image = "docker.io/qmcgaw/gluetun:latest";

          environment = {

          VPN_SERVICE_PROVIDER     = "airvpn";
          VPN_TYPE                 = "wireguard";
          WIREGUARD_PRIVATE_KEY    = secrets.airvpn."wg-privateKey";
          WIREGUARD_ADDRESSES      = "10.174.25.121/32";
          WIREGUARD_PRESHARED_KEY  = secrets.airvpn."wg-presharedKey";
          SERVER_COUNTRIES         = "Netherlands";
          #FIREWALL_VPN_INPUT_PORTS = "";
          TZ                       = "Europe/Stockholm";
          
          };
          extraOptions = [
            "--network=ns:/run/netns/vpn"
            "--cap-add=NET_ADMIN"
            "--device=/dev/net/tun:/dev/net/tun"
          ];
        };
      };
    };
  };

flake.modules.nixos.vpn-gui = { pkgs, user, ... }:
  let
   

    # Runs inside the netns as root, then drops to the calling user.
  inner = pkgs.writeShellScript "vpn-inner" ''
  set -eu
  # Cover host resolver sockets with empty tmpfs mounts (/var/run -> /run on NixOS).
  for d in /run/nscd /run/systemd/resolve; do
    if [ -e "$d" ]; then
      ${pkgs.util-linux}/bin/mount -t tmpfs -o ro,size=4k tmpfs "$d"
    fi
  done
  if [ -S /run/nscd/socket ] || [ -S /var/run/nscd/socket ]; then
    echo "vpn-run: nscd socket still reachable, refusing to start" >&2
    exit 1
  fi
  exec ${pkgs.util-linux}/bin/setpriv \
    --reuid="$SUDO_UID" --regid="$SUDO_GID" --init-groups \
    --inh-caps=-all --bounding-set=-all \
    ${pkgs.coreutils}/bin/env "$@"
'';
# Root entry point. UID comes from sudo, never from an argument.
    outer = pkgs.writeShellScript "vpn-outer" ''
      set -eu
      exec ${pkgs.iproute2}/bin/ip netns exec vpn ${inner} "$@"
    '';

    vpn-run = pkgs.writeShellScriptBin "vpn-run" ''
      if [ "$#" -eq 0 ]; then echo "usage: vpn-run <command> [args]" >&2; exit 1; fi
      exec /run/wrappers/bin/sudo -E ${outer} "$@"
    '';
  in {
    environment.systemPackages = [ vpn-run ];
       networking.firewall.extraCommands = ''
  iptables  -D FORWARD -i vpn-host -j DROP 2>/dev/null || true
  iptables  -D FORWARD -i vpn-host -p udp -m multiport --dports 1637,47107 -j ACCEPT 2>/dev/null || true
  ip6tables -D FORWARD -i vpn-host -j DROP 2>/dev/null || true

  iptables  -I FORWARD 1 -i vpn-host -j DROP
  iptables  -I FORWARD 1 -i vpn-host -p udp -m multiport --dports 1637,47107 -j ACCEPT
  ip6tables -I FORWARD 1 -i vpn-host -j DROP
'';
networking.firewall.extraStopCommands = ''
  iptables  -D FORWARD -i vpn-host -j DROP 2>/dev/null || true
  iptables  -D FORWARD -i vpn-host -p udp -m multiport --dports 1637,47107 -j ACCEPT 2>/dev/null || true
  ip6tables -D FORWARD -i vpn-host -j DROP 2>/dev/null || true
'';

    # Namespaced processes use gluetun's DNS (ip netns exec bind-mounts this over /etc/resolv.conf).
    environment.etc."netns/vpn/resolv.conf".text = "nameserver 127.0.0.1\n";
      environment.etc."netns/vpn/nsswitch.conf".text = ''
  passwd:    files systemd
  group:     files [success=merge] systemd
  shadow:    files
  hosts:     files myhostname dns
  networks:  files
  ethers:    files
  services:  files
  protocols: files
  rpc:       files
'';
    security.sudo.extraRules = [{
      users = [ user ];
      commands = [{
        command = "${outer}";
        options = [ "NOPASSWD" "SETENV" ];
      }];
    }];
  };


}
