{inputs, ... }:

{
  flake.modules.nixos.ai = { lib, pkgs, config,... }:
    let
      inherit (lib) mkIf mkMerge mkOption types;
    in
    {
      imports = [
        ./ai/_llama.nix
        inputs.hermes-agent.nixosModules.default
      ];

      options.ai = {
        backend = mkOption {
          type = types.enum [ "none" "llama" ];
          default = "none";
          description = "Local AI backend to use; use none for cloud-only.";
        };

        harness = mkOption {
          type = types.nullOr (types.enum [ "none" "hermes" ]);
          default = null;
          description = "Optional harness.";
        };

        ui = mkOption {
          type = types.nullOr (types.enum [ "none" "" ]);
          default = null;
          description = "Optional UI.";
        };
      };

      config = mkMerge [
        (mkIf (config.ai.harness == "hermes") {
          services.hermes-agent = {
            enable = true;

            settings.model = {
              default = "Qwen3.5";
              base_url = "http://127.0.0.1:8007/v1";
            };
          };
        })
      ];
    };
}

