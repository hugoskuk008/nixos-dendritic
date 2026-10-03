{...}: {
flake.modules.nixos.system = {lib, pkgs,...}: {

 time.timeZone = "Europe/Stockholm";

nix.settings.experimental-features = ["nix-command" "flakes"];
environment.systemPackages = with pkgs; [
vim
git
wget
alacritty
discord
]; 
system.stateVersion = "26.05";
nixpkgs.config.allowUnfree = true;
  # rtkit (optional, recommended) allows Pipewire to use the realtime scheduler for increased performance.
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
