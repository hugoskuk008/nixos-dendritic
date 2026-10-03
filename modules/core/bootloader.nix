{ ... }:

{
  flake.modules.nixos.bootloader = { lib, ... }: {
    boot.loader = {

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      grub = {
        enable = true;
        efiSupport = true;
        device = "nodev";
        configurationLimit = 20;
      };

      timeout = 5;
    };
  };
}

