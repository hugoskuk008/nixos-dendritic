{
  inputs = {
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";


    
    hermes-agent.url = "github:NousResearch/hermes-agent";
    
    sls-steam.url = "github:AceSLS/SLSsteam";
    sls-steam.inputs.nixpkgs.follows = "nixpkgs";

    acella.url = "github:ciscosweater/enter-the-wired";
    acella.inputs.nixpkgs.follows = "nixpkgs";

    gaze.url = "github:GunduLabs/gaze";
    gaze.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @{ self, ...}:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      

      imports = [
        inputs.flake-parts.flakeModules.modules       
        inputs.home-manager.flakeModules.home-manager
        (inputs.import-tree ./modules)
        ./hosts/Laptroll/laptop.nix
        ./hosts/slaghoken/slaghoken.nix
        ./hosts/nas/nas.nix
      ];
    };
}   

