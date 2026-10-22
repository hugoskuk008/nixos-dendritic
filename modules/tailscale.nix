{...}: {
flake.modules.nixos.tailscale = {pkgs,config, ... }:{

  sops.secrets."tailscale/secretKey" = {mode = "0400"; };
  sops.secrets."tailscale/oauthClientId" = {mode = "0400"; };
  services.tailscale =  {
    enable = true;
    #authKeyFile = config.sops.secrets."tailscale/secretKey".path;
  };

environment.systemPackages = [
pkgs.tailscale-systray
];

};

}
