{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    devenv.url = "github:cachix/devenv";
    devenv.inputs.nixpkgs.follows = "nixpkgs";
  };

  nixConfig = {
    extra-trusted-public-keys = "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=";
    extra-substituters = "https://devenv.cachix.org";
  };

  outputs =
    {
      self,
      nixpkgs,
      devenv,
      systems,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
      ];
      forEachSystem = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forEachSystem (pkgs: {
        devenv-up = self.devShells.${pkgs.stdenv.hostPlatform.system}.default.config.procfileScript;
      });

      formatter = forEachSystem (pkgs: pkgs.nixfmt-tree);

      devShells = forEachSystem (pkgs: {
        default = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            (
              {
                lib,
                pkgs,
                config,
                ...
              }:
              {
                packages = lib.optional pkgs.stdenv.isLinux pkgs.inotify-tools;
                languages.javascript.enable = true;
                languages.elixir.enable = true;
                languages.elixir.package = pkgs.beam29Packages.elixir_1_20;
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
                    { name = "portal_dev"; }
                    { name = "portal_test"; }
                  ];
                };
                git-hooks.hooks = {
                  mix-format.enable = true;
                };
                env = {
                  MIX_ARCHIVES = "${config.devenv.root}/.mix";
                };
              }
            )
          ];
        };
      });
    };
}
