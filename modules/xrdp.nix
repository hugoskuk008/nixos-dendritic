{...}:{

flake.modules.nixos.rdp = {pkgs, ...}: {

  services.xrdp = {
  enable = true;
  defaultWindowManager = "startxfce4";
  openFirewall = true;
};
  services.xserver = {
    enable = true;
    desktopManager = {
      xterm.enable = false;
      xfce.enable = true;
    };
  };

services.xrdp.audio.enable = true;

};
}
