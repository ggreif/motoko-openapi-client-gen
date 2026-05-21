{
  description = "OpenAPI generator nix flake";

  inputs.nixpkgs.url = "github:nixos/nixpkgs";
  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        ocamlPackages = pkgs.ocamlPackages;

        # spec-merge — OpenAPI 3 spec-merger (tools/spec-merge/).
        # Used by samples/client/*/generate.sh whenever a client's
        # generator YAML declares mergeCommand: ... (typically because
        # the API ships its OpenAPI surface across multiple specs and
        # openapi-generator-cli only takes one -i input).
        spec-merge = ocamlPackages.buildDunePackage {
          pname = "spec_merge";
          version = "0.1.0";
          src = ./tools/spec-merge;
          duneVersion = "3";
          propagatedBuildInputs = with ocamlPackages; [
            yaml
            ezjsonm
            cmdliner
          ];
        };
      in
      {
        packages.spec-merge = spec-merge;
        packages.default = spec-merge;

        devShells.default = pkgs.mkShell {
          buildInputs = (with pkgs; [
            jdk17
            maven
            gradle
          ]) ++ [
            spec-merge
          ] ++ (with ocamlPackages; [
            ocaml
            dune_3
            findlib
            yaml
            ezjsonm
            cmdliner
          ]);
        };
      }
    );
}
