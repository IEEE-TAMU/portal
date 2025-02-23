{
  inputs = {
    nixpkgs.url = "github:cachix/devenv-nixpkgs/rolling";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs = {
    self,
    nixpkgs,
    devenv,
    systems,
    ...
  } @ inputs: let
    forEachSystem = nixpkgs.lib.genAttrs (import systems);
  in {
    packages = forEachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      mixNixDeps = pkgs.callPackages ./deps.nix {};
    in rec {
      devenv-up = self.devShells.${system}.default.config.procfileScript;
      default = portal;
      # see https://hexdocs.pm/phoenix/releases.html and
      # https://github.com/code-supply/nix-phoenix/tree/main/flake-template
      # for more information
      portal = with pkgs;
        beamPackages.mixRelease {
          inherit mixNixDeps;
          pname = "ieee-tamu-portal";
          src = ./.;
          version = "0.0.0";

          # make runtime.ex happy during build
          NIX_BUILD_ENV = "true";

          # generate phx overlays (migrate and server)
          preBuild = ''
            mix phx.gen.release
          '';

          postBuild = ''
            tailwind_path="$(mix do \
              app.config --no-deps-check --no-compile, \
              eval 'Tailwind.bin_path() |> IO.puts()')"
            esbuild_path="$(mix do \
              app.config --no-deps-check --no-compile, \
              eval 'Esbuild.bin_path() |> IO.puts()')"

            ln -sfv ${tailwindcss}/bin/tailwindcss "$tailwind_path"
            ln -sfv ${esbuild}/bin/esbuild "$esbuild_path"
            ln -sfv ${mixNixDeps.heroicons} deps/heroicons

            mix do \
              app.config --no-deps-check --no-compile, \
              assets.deploy --no-deps-check
          '';
        };
    });

    formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.alejandra);

    devShells =
      forEachSystem
      (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            {
              languages.elixir.enable = true;
              services.mysql = {
                enable = true;
                ensureUsers = [
                  {
                    name = "portal";
                    password = "portal";
                    ensurePermissions = {
                      "portal_dev.*" = "ALL PRIVILEGES";
                      "portal_test.*" = "ALL PRIVILEGES";
                    };
                  }
                ];
                initialDatabases = [
                  {name = "portal_dev";}
                  {name = "portal_test";}
                ];
              };
              pre-commit.hooks = {
                alejandra.enable = true;
                alejandra.settings.exclude = ["deps.nix"];
                mix-format.enable = true;
              };
            }
          ];
        };
      });
  };
}
