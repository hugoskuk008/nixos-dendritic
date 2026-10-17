{...}: {
flake.modules.nixos.tailscale = {pkgs, ... }:{
services.tailscale.enable = true;

environment.systemPackages = [
pkgs.tailscale-systray
];

};

}
