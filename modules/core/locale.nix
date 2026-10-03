{ ... }: {
  flake.modules.nixos.locale = { lib,... }: {
    i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";

    services.xserver.xkb = {
      layout  = lib.mkDefault "se";
      variant = lib.mkDefault "";
    };

    console.useXkbConfig = lib.mkDefault true;
  };
}   
