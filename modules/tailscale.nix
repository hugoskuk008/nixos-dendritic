{...}: {
flake.modules.nixos.tailscale = {pkgs,config, ... }:{

  sops.secrets."tailscale/secretKey" = {mode = "0400"; };
  sops.secrets."tailscale/oauthClientId" = {mode = "0400"; };

  services.tailscale = {
      enable = true;
      useRoutingFeatures = "both";
    };


    networking.firewall.trustedInterfaces = [ "tailscale0" ];
  systemd.services.tailscale-mtu = {
    description = "Set Tailscale interface MTU";
    after = [ "tailscaled.service" ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      ${pkgs.iproute2}/bin/ip link set dev tailscale0 mtu 1000
    '';
  };

environment.systemPackages = [
pkgs.tailscale-systray
];

};

}
