{ config, lib, pkgs, pkgs-unstable, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "nas";
  networking.hostId = "251d2bb4";
  boot.zfs.forceImportRoot = false;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.initrd.supportedFilesystems = [ "zfs" ];
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  boot.kernelModules = [ "zfs" ];
  boot.zfs.extraPools = [ "nas-array" ];    
      services.zfs = {
        autoScrub = {
          enable = true;
          interval = "monthly";
        };
        trim.enable = true;
      };

nixpkgs.config.allowUnfree = true;
  environment.systemPackages = with pkgs; [
    htop
    git
    neovim
    smartmontools
      zfs
      sops
    kitty
    btop
    wl-clipboard
    lemonade
];
 services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {

    # Modesetting is required.
    modesetting.enable = true;



    open = true;

    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  users.users.admin = {
    isNormalUser = true;
    uid = 1000;   # match TrueNAS UID
    extraGroups = [ "wheel" ];
   # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  };
nix.settings.experimental-features = ["nix-command" "flakes"];

  system.stateVersion = "26.05";   


} 

