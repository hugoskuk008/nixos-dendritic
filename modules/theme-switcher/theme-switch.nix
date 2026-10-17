{...}:{
flake.modules.homeManager.theme-switch =
{ pkgs, ... }: 

let
  # writeShellApplication runs ShellCheck at build time and fails the build on
  # any finding, and pins runtime dependencies on PATH.
  theme-switch = pkgs.writeShellApplication {
    name = "theme-switch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.hostname
    ];
    text = builtins.readFile ./theme-switch.sh;
  };
in
{
  home.packages = [ theme-switch ];
};}
