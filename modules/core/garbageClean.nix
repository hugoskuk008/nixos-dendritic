{...}:{

flake.modules.nixos.garbagecleaner = {

nix.gc = {
    automatic = true;
    dates = "*-*-1/3 00:00:00";
    options = "-d";



    };
  };
}
