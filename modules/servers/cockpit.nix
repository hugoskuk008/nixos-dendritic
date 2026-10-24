{ ... }:
{
  flake.modules.nixos.cockpit = { config, ... }:
    let
      port = 9090;
      fqdn = "cockpit-${config.networking.hostName}.${config.homelab.domain}";
    in
    {
      homelab.services.cockpit = { inherit port; perHost = true; };

      services.cockpit = {
        enable = true;
        inherit port;
        openFirewall = true;

        allowed-origins = [
          "http://${fqdn}"
          "ws://${fqdn}"
          "https://${fqdn}"
          "wss://${fqdn}"
        ];

        settings.WebService = {
          ProtocolHeader = "X-Forwarded-Proto";
          AllowUnencrypted = true;
        };
      };
    };
}
