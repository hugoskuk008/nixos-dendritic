{ config, lib, pkgs, ... }:
{
  specialisation.nvidia-offload.configuration = {
   



   system.nixos.tags = [ "nvidia-offload" ];
 






services.xserver.videoDrivers = [ "nvidia" "amdgpu" ];
    hardware.graphics.enable = true;
boot.extraModprobeConfig = ''
  options nvidia NVreg_EnableS0ixPowerManagement=1
'';
     

    hardware.nvidia = {
      package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "595.99.02";
        sha256_64bit = "sha256-6HR3lYv3YwcFSTJL1a1slI66btIQ5EAFs+/4SUD24ew=";
        sha256_aarch64 = "sha256-CCqHZTN2KNOZ4yZp2rDcuRJp9pHfRw47k4m4dWnS/2w=";
        openSha256 = "sha256-T36x/jx8yQ8l3LFp1rZIrTfcSwbGy8YSAvXOUSptpb4=";
        settingsSha256 = "sha256-GYCcnxfKPrTCrsmd25sMyzfC5cqJQJx0c31haooyTYM=";
        persistencedSha256 = "sha256-VyKtF/HdHPQrHHK6opSO69M72LmnGZtauuchj9uuje8=";
      };

      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;

      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        amdgpuBusId = "PCI:101:0:0";
        nvidiaBusId = "PCI:100:0:0";
      };
    };
  

 
hardware.asusDgpu.disable = false;
    

  

};
}
