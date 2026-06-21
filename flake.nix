{
  description = "KernelDesk development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      kernelDeskPackages = pkgs: [
        pkgs.elmPackages.elm
        pkgs.elmPackages.elm-format
        pkgs.elmPackages.elm-language-server
        pkgs.elmPackages.elm-test
        pkgs.git
        pkgs.gleam
        pkgs.nil
        pkgs.nixfmt
        pkgs.nodejs_22
      ];

      kernelDeskApp =
        pkgs: name: command:
        let
          script = pkgs.writeShellApplication {
            name = "kernel-desk-${name}";
            runtimeInputs = kernelDeskPackages pkgs;
            text = command;
          };
        in
        {
          type = "app";
          program = "${script}/bin/kernel-desk-${name}";
        };
    in
    {
      apps = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
          app = kernelDeskApp pkgs;
        in
        {
          default = app "dev" "npm run dev";
          build = app "build" "npm run build";
          check = app "check" ''
            npm run build:frontend:debug
            npm run check:backend
            npm run verify:local
          '';
          dev = app "dev" "npm run dev";
          linux-clone = app "linux-clone" "npm run linux:clone";
          linux-clone-shallow = app "linux-clone-shallow" "npm run linux:clone:shallow";
          linux-start = app "linux-start" "npm run linux:start";
          linux-dev = app "linux-dev" "npm run linux:dev";
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = kernelDeskPackages pkgs;

            shellHook = ''
              echo "KernelDesk dev shell"
              echo "  node  $(node --version)"
              echo "  npm   $(npm --version)"
              echo "  gleam $(gleam --version)"
              echo "  elm   $(elm --version)"
              echo "  elm-format        $(command -v elm-format)"
              echo "  elm-test          $(command -v elm-test)"
              echo "  elm-language-server $(command -v elm-language-server)"
              echo "  nixfmt            $(command -v nixfmt)"
            '';
          };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.writeShellApplication {
          name = "kernel-desk-fmt";
          runtimeInputs = [ pkgs.nixfmt ];
          text = "nixfmt flake.nix";
        }
      );
    };
}
