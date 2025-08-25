{
  description = "hoprnet rfc repository";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.05";
    pre-commit.url = "github:cachix/git-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    flake-root.url = "github:srid/flake-root";

    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    pre-commit.inputs.nixpkgs.follows = "nixpkgs";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      pre-commit,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.flake-root.flakeModule
      ];
      perSystem =
        {
          config,
          lib,
          system,
          ...
        }:
        let
          localSystem = system;
          overlays = [
          ];
          pkgs = import nixpkgs { inherit localSystem overlays; };
          pre-commit-check = pre-commit.lib.${system}.run {
            src = ./.;
            hooks = {
              # https://github.com/cachix/git-hooks.nix
              treefmt.enable = false;
              treefmt.package = config.treefmt.build.wrapper;
              check-executables-have-shebangs.enable = true;
              check-shebang-scripts-are-executable.enable = true;
              check-case-conflicts.enable = true;
              check-symlinks.enable = true;
              check-merge-conflicts.enable = true;
              check-added-large-files.enable = true;
              commitizen.enable = true;
            };
            tools = pkgs;
            excludes = [
            ];
          };

          devShell = pkgs.mkShell {
            buildInputs = [
              config.treefmt.build.wrapper
            ]
            ++ (pkgs.lib.attrValues config.treefmt.build.programs);
          };
        in
        {
          treefmt = {
            inherit (config.flake-root) projectRootFile;

            programs.prettier.enable = true;

            settings.global.excludes = [
              "**/.gitignore"
              ".editorconfig"
              ".gitattributes"
              "LICENSE"
            ];
            settings.formatter.prettier.includes = [
              "*.md"
              "*.json"
            ];
            settings.formatter.prettier.excludes = [
              "*.yml"
              "*.yaml"
            ];
            # using the official Nixpkgs formatting
            # see https://github.com/NixOS/rfcs/blob/master/rfcs/0166-nix-formatting.md
            programs.nixfmt.enable = true;
          };

          packages = {
            inherit pre-commit-check;
          };

          devShells.default = devShell;

          formatter = config.treefmt.build.wrapper;
        };
      # platforms which are supported as build environments
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
    };
}
