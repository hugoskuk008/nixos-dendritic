{ inputs, user, ... }:
{
  flake.modules.nixos.sops = { config, lib, pkgs, user, ... }: {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    sops = {
      defaultSopsFile = ../../secrets/secrets.json;
      defaultSopsFormat = "json";

      age.sshKeyPaths = [ "/home/${user}/.ssh/slaghoken" ];

      secrets."github/token" = {

          mode  = "0400"; 

        };
      validateSopsFiles = false;
    };
  };
}
