{...}: {
flake.modules.nixos.system = {lib, pkgs,...}: {

 time.timeZone = "Europe/Stockholm";

nix.settings.experimental-features = ["nix-command" "flakes"];
environment.systemPackages = with pkgs; [
vim
git
btop
wget
git-crypt
]; 
system.stateVersion = "26.05";
hardware.enableRedistributableFirmware = true;
nixpkgs.config.allowUnfree = true;
  security.rtkit.enable = true;
  
  services.pipewire = {
    enable = true; # if not already enabled
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment the following
    #jack.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    };
  
};
}
