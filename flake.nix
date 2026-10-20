{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    sls-steam.url = "github:AceSLS/SLSsteam";
    acella.url = "github:ciscosweater/enter-the-wired";
  
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @{ self, ...}: let
in 
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      

      imports = [
        inputs.flake-parts.flakeModules.modules       
        inputs.home-manager.flakeModules.home-manager
        (inputs.import-tree ./modules)
        ./hosts/Laptroll/laptop.nix
        ./hosts/slaghoken/slaghoken.nix
      ];
    };
}   

