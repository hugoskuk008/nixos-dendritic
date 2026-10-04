{...}:{

flake.modules.nixos.rdp = {pkgs, ...}: {

  services.xrdp = {
  enable = true;
  defaultWindowManager = "startxfce4";
  openFirewall = true;
};



services.xrdp.audio.enable = true;

};
}
