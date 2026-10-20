{inputs,...}:{
flake.modules.nixos.gaze = { ... }: {
  imports = [
    inputs.gaze.nixosModules.default
  ];

  services.gaze = {
    enable = true;
    gui.enable = true;
  };
};
}
