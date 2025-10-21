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
              # Formatting with treefmt
              treefmt.enable = true;
              treefmt.package = config.treefmt.build.wrapper;

              # Git repository checks
              check-executables-have-shebangs.enable = true;
              check-shebang-scripts-are-executable.enable = true;
              check-case-conflicts.enable = true;
              check-symlinks.enable = true;
              check-merge-conflicts.enable = true;
              check-added-large-files.enable = true;

              # Commit message formatting
              commitizen.enable = true;

              # Spell checking
              cspell = {
                enable = true;
                name = "cspell";
                entry = "${pkgs.nodePackages.cspell}/bin/cspell --no-progress";
                files = "\\.md$";
                types = [ "text" ];
              };
            };
            tools = pkgs;
            excludes = [
            ];
          };

          devShell = pkgs.mkShell {
            inherit (pre-commit-check) shellHook;
            buildInputs =
              with pkgs;
              [
                # Task runner and formatting
                just
                config.treefmt.build.wrapper

                # Spell checking
                nodePackages.cspell
              ]
              ++ (pkgs.lib.attrValues config.treefmt.build.programs);
          };
        in
        {
          treefmt = {
            inherit (config.flake-root) projectRootFile;

            programs.prettier = {
              enable = true;
              settings = {
                printWidth = 150;
                proseWrap = "always";
                tabWidth = 2;
                useTabs = false;
              };
            };

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
