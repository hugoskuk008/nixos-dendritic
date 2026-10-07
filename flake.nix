{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    sls-steam.url = "github:AceSLS/SLSsteam";
    acella.url = "github:ciscosweater/enter-the-wired";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @{ self, ...}: let
secrets = builtins.fromJSON (builtins.readFile "${self}/secrets/secrets.json");
in 
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      
       _module.args.secrets = secrets;

      imports = [
        inputs.flake-parts.flakeModules.modules       
        inputs.home-manager.flakeModules.home-manager
        (inputs.import-tree ./modules)
        ./hosts/laptop/laptop.nix
        ./hosts/slaghoken/slaghoken.nix
      ];
    };
}   

