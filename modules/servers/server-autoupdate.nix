
{ ... }:
{
  flake.modules.nixos.server-autoupdate =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.nasFlakeUpdater;

      updater = pkgs.writeShellScript "nas-flake-update" (
        builtins.readFile ./_lib/nas-flake-update.sh
      );

      commonEnvironment = {
        NAS_UPDATE_REPO = /home/admin/nixos-dendritic;
        NAS_UPDATE_USER = "admin";

        NAS_UPDATE_URL =
          "https://ntfy.${config.homelab.domain}/update";

        NAS_UPDATE_TOKEN_FILE =
          config.sops.secrets."nas-update/ntfy-token".path;

        NAS_UPDATE_STATE_DIR =
          "/var/lib/nas-flake-update";
      };

      commonPath = with pkgs; [
        bash
        coreutils
        curl
        git
        gnugrep
        nix
        nixos-rebuild
        systemd
        util-linux
      ];
    in
    {
      options.services.nasFlakeUpdater.repoDir =
        lib.mkOption {
          type = lib.types.str;
          default = "/home/admin/nixos-dendritic";
          description = "Writable NAS flake Git checkout.";
        };

      # Disable the generic updater to prevent conflicts.
      system.autoUpgrade.enable = lib.mkForce false;

      # Authenticated ntfy publisher token.
      sops.secrets."nas-update/ntfy-token" = {
        mode = "0400";
      };

      # Update flake.lock, commit, build, and reboot.
      systemd.services.nas-flake-update = {
        description = "Automatic NAS flake update";

        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];

        path = commonPath;
        environment = commonEnvironment;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${updater} run";
          StateDirectory = "nas-flake-update";
          StateDirectoryMode = "0700";
          TimeoutStartSec = "infinity";
        };
      };

      # Every Wednesday at 04:35 Stockholm time.
      systemd.timers.nas-flake-update = {
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnCalendar = "Wed *-*-* 04:35:00 Europe/Stockholm";
          AccuracySec = "1s";
          RandomizedDelaySec = "0";
          Persistent = false;
        };
      };

      # Verify the generation after reboot and notify ntfy.
      systemd.services.nas-flake-update-finish = {
        description = "Report NAS update after reboot";

        wants = [ "network-online.target" ];

        after = [
          "network-online.target"
          "tailscaled.service"
          "docker-ntfy.service"
        ];

        path = commonPath;
        environment = commonEnvironment;

        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${updater} finish";
          StateDirectory = "nas-flake-update";
          StateDirectoryMode = "0700";
          TimeoutStartSec = "2min";
        };
      };

      # Retry post-boot notification when network is unavailable.
      systemd.timers.nas-flake-update-finish = {
        wantedBy = [ "timers.target" ];

        timerConfig = {
          OnBootSec = "2min";
          OnUnitInactiveSec = "5min";
          AccuracySec = "30s";
        };
      };
    };
}

