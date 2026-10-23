{ ... }:
{
  flake.modules.nixos.proxy = { config, lib, pkgs, ... }: {
    options.myProxy.vhosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Local proxy routes contributed by service modules.";
    };
    config = {
      services.caddy = {
        enable = true;

               globalConfig = "local_certs";

        virtualHosts = builtins.mapAttrs
          (_domain: upstream: {
            extraConfig = "reverse_proxy ${upstream}";
          })
          config.myProxy.vhosts;
      };

      networking.firewall.allowedTCPPorts = [ 80 443 ];
    };
  };
}
