{
  description = "status-web: thin viewer for status-api (ReScript)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      perSystem =
        { pkgs, ... }:
        {
          # 웹 루트 디렉터리 하나: index.html, style.css, app.js
          packages.default = pkgs.callPackage ./package.nix { };
          devShells.default = pkgs.mkShell {
            packages = [
              pkgs.nodejs
              pkgs.esbuild
            ];
          };
        };
    };
}
