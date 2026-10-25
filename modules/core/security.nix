{...}:{
flake.modules.nixos.security = {pkgs, user,...}: {
    users.users.${user}.openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKMsgfbJfwUBXpavrKYOe6ySt7PSuKQOjZbkcz1XbTTb"];
  services.openssh = {
  enable = true;
  openFirewall = true;
  settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "no";
    AllowUsers = [ "admin" ];
    MaxAuthTries = 3;
    PerSourcePenalties = "crash:3600s authfail:3600s max:86400s";
      };
    };
  services.fail2ban = {
    enable = true;
    maxretry = 5;
    bantime = "24h";

    bantime-increment = {
#      formula = "ban.Time * math.exp(float(ban.Count+1)*banFactor)/math.exp(1*banFactor)";
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h"; # Do not ban for more than 1 week
      overalljails = true; # Calculate the bantime based on all the violations
      };
    };
  networking.firewall = {
    enable = true;
    allowPing = false;
    checkReversePath = "loose";
    backend = "iptables";
    pingLimit = "--limit 1/minute --limit-burst 5";
    allowedTCPPorts = [
       22 443

      ];
    allowedUDPPorts = [
     
      ];
    };
environment.systemPackages = with pkgs; [
  lynis

    ];
  };
}
