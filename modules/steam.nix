{ inputs, lib, ... }:
{
  flake.modules.nixos.steam = { pkgs, config, ... }:
  let
    system = pkgs.stdenv.hostPlatform.system;
    sls-steam = inputs.sls-steam.packages.${system}.default;
    acella = inputs.acella.packages.${system}.default;
 in
  {
    environment.systemPackages = [ sls-steam acella ];

    programs.steam = {
      enable = true;
      protontricks.enable = true;
      extraCompatPackages = with pkgs; [ proton-ge-bin ];
      package = pkgs.steam.override {
        extraEnv = {
          LD_AUDIT = "${sls-steam}/library-inject.so:${sls-steam}/SLSsteam.so";
        };
      };
    };

    programs.gamemode.enable = true;
  };
}
