{ ... }:

{
  flake.modules.nixos.bootloader = { lib, ... }: {
    boot.loader = {
      systemd-boot.enable = lib.mkForce false;

      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };

      grub = {
        enable = lib.mkForce true;
        efiSupport = true;
        device = "nodev";
        configurationLimit = 20;
      };

      timeout = 5;
    };
  };
}

