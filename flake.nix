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
    packages = forEachSystem (system: {
      devenv-up = self.devShells.${system}.default.config.procfileScript;
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
                mix-format.enable = true;
              };
            }
          ];
        };
      });
  };
}
