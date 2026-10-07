{ ... }: {
  flake.modules.nixos.ryzenadj = { config, lib, pkgs, ... }: {
    config = lib.mkIf config.services.tlp.enable {
      environment.systemPackages = [ pkgs.ryzenadj ];

      systemd.services.ryzenadj = {
        description = "Apply RyzenAdj power limits";
        wantedBy = [ "multi-user.target" "post-resume.target" ];
        after = [ "post-resume.target" ];
        path = [ pkgs.ryzenadj ];
        serviceConfig.Type = "oneshot";
        script = ''
           ryzenadj --stapm-limit=8000 --fast-limit=10000 --slow-limit=8000
           
        '';
      };

      services.udev.extraRules = ''
        SUBSYSTEM=="power_supply", ACTION=="change", TAG+="systemd", ENV{SYSTEMD_WANTS}="ryzenadj.service"
      '';
    };
  };
}
