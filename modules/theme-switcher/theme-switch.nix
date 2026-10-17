{ ... }:

let
  mkThemeSwitch =
    pkgs:
    pkgs.writeShellApplication {
      name = "theme-switch";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.hostname
        pkgs.jq
      ];
      text = builtins.readFile ./theme-switch.sh;
    };

  mkThemeSwitchPicker =
    pkgs:
    pkgs.writeShellApplication {
      name = "theme-switch-picker";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.libnotify
        pkgs.rofi
        (mkThemeSwitch pkgs)
      ];
      text = builtins.readFile ./theme-switch-picker.sh;
      meta = {
        description = "Rofi thumbnail picker for theme-switch";
        mainProgram = "theme-switch-picker";
        license = pkgs.lib.licenses.mit;
      };
    };
in
{
  flake.modules.homeManager.theme-switch =
    { pkgs, ... }:
    {
      home.packages = [ (mkThemeSwitch pkgs) ];
    };

  flake.modules.homeManager.theme-switch-gui =
    { pkgs, ... }:
    {
      home.packages = [ (mkThemeSwitchPicker pkgs) ];
    };
}
