{...}: {

flake.modules.nixos.qemu = {pkgs, user, ...}: {

environment.systemPackages = [
  pkgs.qemu
];
systemd.tmpfiles.rules = [ "L+ /var/lib/qemu/firmware - - - - ${pkgs.qemu}/share/qemu/firmware" ];

programs.virt-manager.enable = true;

users.groups.libvirtd.members = ["${user}"];

virtualisation.libvirtd.enable = true;

virtualisation.spiceUSBRedirection.enable = true;

};


}
