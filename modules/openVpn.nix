{...}:{
flake.modules.nixos.openVpn = {pkgs,...}:{
  services.openvpn.servers.europe = {
    config = ''
      config /var/lib/ovpn/AirVPN_Europe_TCP-443-Entry3.ovpn
    '';
    };

    networking.networkmanager = {
    plugins = with pkgs; [
      networkmanager-openvpn
    ];
  };
  };
}
