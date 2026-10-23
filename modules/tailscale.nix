{...}: {
flake.modules.nixos.tailscale = {pkgs,config, ... }:{

  sops.secrets."tailscale/secretKey" = {mode = "0400"; };
  sops.secrets."tailscale/oauthClientId" = {mode = "0400"; };

  services.tailscale = {
      enable = true;
      useRoutingFeatures = "both";
    };

    services.tailscale.permitCertUid = "caddy";

    networking.firewall.trustedInterfaces = [ "tailscale0" ];


environment.systemPackages = [
pkgs.tailscale-systray
];

};

}
