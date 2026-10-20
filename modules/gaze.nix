{inputs,...}:{
flake.modules.nixos.gaze = { ... }: {
  imports = [
    inputs.gaze.nixosModules.default
  ];
    services.gaze.gnome.enableForUsers = true;
    services.gaze.gnome.gdmFaceLogin = true;
    services.gaze.gnome.enable = true;
  services.gaze = {
    enable = true;
    gui.enable = true;
  };
};
}
