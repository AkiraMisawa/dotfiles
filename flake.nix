{
  description = "amisa's dotfiles";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      mkHome = { system, username, homeDirectory, extraModules ? [ ] }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};
          modules = [
            ./home.nix
            { home = { inherit username homeDirectory; }; }
          ] ++ extraModules;
        };
    in {
      homeConfigurations = {
        # WSL (Ubuntu)
        "amisa@wsl" = mkHome {
          system = "x86_64-linux";
          username = "amisa";
          homeDirectory = "/home/amisa";
        };

        # Placeholder for future hosts — duplicate and adjust:
        # "amisa@mac" = mkHome {
        #   system = "aarch64-darwin";
        #   username = "amisa";
        #   homeDirectory = "/Users/amisa";
        # };
        # "amisa@ubuntu" = mkHome {
        #   system = "x86_64-linux";
        #   username = "amisa";
        #   homeDirectory = "/home/amisa";
        # };
      };
    };
}
