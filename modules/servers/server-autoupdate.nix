{ ... }:
{
  # Enabled as server-autoupdate via hosts/nas/modules.json.
  flake.modules.nixos.server-autoupdate = { config, lib, pkgs, ... }:
    let
      cfg = config.services.nasFlakeUpdater;
      updater = pkgs.writeShellScript "nas-flake-update" (
        builtins.readFile ./_lib/nas-flake-update.sh
      );
      commonEnvironment = {
        NAS_UPDATE_REPO = cfg.repoDir;
        NAS_UPDATE_USER = "admin";
        NAS_UPDATE_URL = "https://ntfy.${config.homelab.domain}/update";
        NAS_UPDATE_TOKEN_FILE = config.sops.secrets."nas-update/ntfy-token".path;
        NAS_UPDATE_STATE_DIR = "/var/lib/nas-flake-update";
      };
      commonPath = with pkgs; [
        bash coreutils curl git gnugrep nix nixos-rebuild systemd util-linux
      ];
    in
    {
      options.services.nasFlakeUpdater.repoDir = lib.mkOption {
        type = lib.types.str;
        default = "/home/admin/nixos-dendritic";
        description = "Writable Git worktree containing the NAS flake.";
      };

      config = {
      # The old generic updater must never race with this Git-aware updater.
      system.autoUpgrade.enable = lib.mkForce false;

      sops.secrets."nas-update/ntfy-token" = {
        mode = "0400";
      };

      systemd.services.nas-flake-update = {
        description = "Update NAS flake inputs, commit, build and reboot";
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

      systemd.timers.nas-flake-update = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Wed *-*-* 04:35:00 Europe/Stockholm";
          AccuracySec = "1s";
          RandomizedDelaySec = "0";
          Persistent = false;
        };
      };

      # Send FINISHED only when the machine has actually rebooted into
      # the generation we staged. Retry if ntfy/Tailscale is not yet ready.
      systemd.services.nas-flake-update-finish = {
        description = "Report NAS flake update outcome after reboot";
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

      systemd.timers.nas-flake-update-finish = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitInactiveSec = "5min";
          AccuracySec = "30s";
        };
      };
      };
    };
}
