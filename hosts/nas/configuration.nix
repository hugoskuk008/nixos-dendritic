{ config, lib, pkgs, pkgs-unstable, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nas";
  networking.hostId = "251d2bb4";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_6_18;

  boot.zfs.extraPools = [ "nas-array" ];

      services.zfs = {
        autoScrub = {
          enable = true;
          interval = "monthly";
        };
        trim.enable = true;
      };


  environment.systemPackages = with pkgs; [
    htop
    git
    neovim
    smartmontools
  ];

  services.openssh.enable = true;

  users.users.admin = {
    isNormalUser = true;
    uid = 950;   # match TrueNAS UID
    extraGroups = [ "wheel" ];
   # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  };

  system.stateVersion = "26.05";   
  }
