{...}: {
flake.modules.nixos.tailscale = {pkgs, ... }:{

  sops.secrets."tailscale/secretKey" = {mode = "0400"; };
  sops.secrets."tailscale/oauthClientId" = {mode = "0400"; };
  services.tailscale =  {
    enable = true;
    authKeyFile = /run/secrets/tailscale/secretKey;
  };

environment.systemPackages = [
pkgs.tailscale-systray
];

};

}
