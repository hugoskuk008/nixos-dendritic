{ self, inputs, ... }:
{
  perSystem = { system, self', ... }: {
    packages.modules-ctl =
      inputs.nixpkgs.legacyPackages.${system}.callPackage ../../tools/modules-ctl/package.nix { };

    # `nix flake check` then runs the tool's unit tests.
    checks.modules-ctl = self'.packages.modules-ctl;
  };

  # A switchable module like any other: enable "modules-ctl" for a host to put the command on PATH.
  flake.modules.nixos.modules-ctl = { pkgs, ... }: {
    environment.systemPackages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.modules-ctl
    ];
  };
}
