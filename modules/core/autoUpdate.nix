{...}:{

flake.modules.nixos.autoupdates = {
  system.autoUpgrade = {
    enable = true;
    dates = "weekly";
    randomizedDelaySec = "45min";
    allowReboot = false;
    };
  };
}
