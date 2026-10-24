{ inputs, self,config, ... }:
let
  system = "x86_64-linux";
  args = {
    configname       = "nas";
    user             = "admin";
    sopsSshkey       = "/home/admin/.ssh/slaghoken";
    currentTheme     = "gruvbox";
    internetInterface = "enp5s0";
  };
  mkHost = import ../mk-host.nix { inherit inputs config; };
in
{

  flake.nixosConfigurations.nas = mkHost {
    name      = "nas";
    inherit (args) user;
    selection = ./modules.json;
    specialArgs = {
      inherit args;
      inherit (args) internetInterface configname user sopsSshkey;
    };
    extraModules = [
      ./hardware-configuration.nix
      ./configuration.nix
      ({ config, ... }: {
        homelab.address = "192.168.10.10";      
        homelab.domain  = "home.hogcloud.bid";

        services.tailscale.extraSetFlags = [ "--advertise-routes=192.168.10.0/24" ];

        sops.secrets."acme/cloudflareToken" = { };
        homelab.ingress.acme = {
          enable = true;
          email = "jackansen2007@proton.me";            
          staging = false;                                
          credentialFiles.CLOUDFLARE_DNS_API_TOKEN_FILE =
            config.sops.secrets."acme/cloudflareToken".path;
        };
        fileSystems."/docker" = {
        device = "/nas-array/docker";
        fsType = "none";
        options = [
         "bind"
         "x-systemd.requires=zfs-mount.service"
          "x-systemd.after=zfs-mount.service"
         ];
        };

        fileSystems."/data" = {
        fsType = "none";
        device = "/nas-array/subvol-100-disk-0/";
        options = [
          "bind"
          "x-systemd.requires=zfs-mount.service"
          "x-systemd.after=zfs-mount.service"
           ];
         };

        home-manager.useGlobalPkgs               = true;
        home-manager.backupFileExtension         = null;
        home-manager.extraSpecialArgs            = args;
        home-manager.users.${args.user}.home.stateVersion = "26.05";
      })
    ];
  };
  }
