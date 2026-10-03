{ ... }:{
flake.modules.nixos.dgpuService = {config, lib, pkgs, ...}:

let
  dgpuDisable = config.hardware.asusDgpu.disable;
in
{
  options.hardware.asusDgpu.disable = lib.mkOption {
    type = lib.types.bool;
    default = true;
  };

  config = {
    systemd.services.dgpu-power = {
      description = "Configure dGPU power state";
      wantedBy = [ "sysinit.target" ];
      before = [ "nvidia-suspend.service" ];

      unitConfig.DefaultDependencies = false;

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        ExecStart = pkgs.writeShellScript "configure-dgpu" ''
          echo ${if dgpuDisable then "1" else "0"} \
            > /sys/devices/platform/asus-nb-wmi/dgpu_disable
        '';
      };
    };
  };
};
}

