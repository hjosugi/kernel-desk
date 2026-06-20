{
  description = "KernelDesk development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { nixpkgs, ... }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.elmPackages.elm
              pkgs.elmPackages.elm-format
              pkgs.elmPackages.elm-language-server
              pkgs.elmPackages.elm-test
              pkgs.git
              pkgs.gleam
              pkgs.nil
              pkgs.nodejs_22
            ];

            shellHook = ''
              echo "KernelDesk dev shell"
              echo "  node  $(node --version)"
              echo "  npm   $(npm --version)"
              echo "  gleam $(gleam --version)"
              echo "  elm   $(elm --version)"
              echo "  elm-format        $(command -v elm-format)"
              echo "  elm-test          $(command -v elm-test)"
              echo "  elm-language-server $(command -v elm-language-server)"
            '';
          };
        });
    };
}
