{ config, lib, pkgs, ... }:

let
  llamaCppRocm = pkgs.llama-cpp-rocm;
  llamaServer = lib.getExe' llamaCppRocm "llama-server";
in
{
  config = lib.mkIf (config.ai.backend == "llama") {
    systemd.services.llama-swap.serviceConfig.SupplementaryGroups = [
      "render"
      "video"
    ];
    services.llama-swap = {
      enable = true;
      listenAddress = "127.0.0.1";
      port = 8007;

      settings.models = {

      "Qwen3.5" = {
        cmd = ''
          ${llamaServer}
          --port ''${PORT}
          --model /var/lib/llama-swap/models/Qwen3.5-9B-abliterated-Q8_0.gguf
          --n-gpu-layers 999
          --temp 0.8
          --repeat-penalty 1.05
          --top-k 80
          --no-webui
        '';
        aliases = [ "Qwen3.5" ];
        };
      
      };
    };
  };
}

