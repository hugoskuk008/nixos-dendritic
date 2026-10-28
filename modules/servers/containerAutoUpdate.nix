 {...}:{
flake.modules.nixos.updateContainers = {lib,pkgs,...}:

{
  systemd.timers.update-containers = {
    timerConfig = {
      Unit = "update-containers.service";
      OnCalendar = "Mon 02:00";
    };
    wantedBy = [ "timers.target" ];
  };
  systemd.services.update-containers = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe (pkgs.writeShellScriptBin "update-containers" ''
        images=$(${pkgs.docker}/bin/docker ps -a --format="{{.Image}}" | sort -u)

        for image in $images; do
          ${pkgs.docker}/bin/docker pull "$image"
        done
      '');
    };
  };
};
}
