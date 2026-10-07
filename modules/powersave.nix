{ ... }: {
  flake.modules.nixos.ryzenadj = { config, lib, pkgs, ... }: {
    config = lib.mkIf config.services.tlp.enable {
      environment.systemPackages = [ pkgs.ryzenadj ];

      systemd.services.ryzenadj = {
        description = "Apply RyzenAdj power limits";
        wantedBy = [ "multi-user.target" "post-resume.target" ];
        after = [ "post-resume.target" "tlp.service" ];
        path = [ pkgs.tlp pkgs.ryzenadj ];
        serviceConfig.Type = "oneshot";
        script = ''
          tlp-run-on bat ryzenadj --stapm-limit=8000 --fast-limit=10000 --slow-limit=8000
          tlp-run-on ac ryzenadj --stapm-limit=28000 --fast-limit=35000 --slow-limit=28000
        '';
      };

      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}="ryzenadj.service"
      '';
    };
  };
}
