{
  description = "akira's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      mkHome = { system, username, homeDirectory, gitName, gitEmail
               , extraModules ? [ ] }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          extraSpecialArgs = { inherit gitName gitEmail; };
          modules = [
            ./home.nix
            { home = { inherit username homeDirectory; }; }
          ] ++ extraModules;
        };
    in {
      homeConfigurations = {
        "akira@wsl" = mkHome {
          system = "x86_64-linux";
          username = "akira";
          homeDirectory = "/home/akira";
          gitName  = "akira";
          gitEmail = "4346607+AkiraMisawa@users.noreply.github.com";
        };

        "akira338@mac" = mkHome {
          system = "aarch64-darwin";
          username = "akira338";
          homeDirectory = "/Users/akira338";
          gitName  = "akira";
          gitEmail = "4346607+AkiraMisawa@users.noreply.github.com";
        };
      };
    };
}
