# dotfiles

Cross-platform dotfiles managed with Nix flakes + home-manager.

## Apply

```sh
nix run home-manager/master -- switch --flake .#amisa@wsl -b backup
```

Replace `amisa@wsl` with the target host config in `flake.nix`.

After the first switch, `home-manager` is on PATH:

```sh
home-manager switch --flake ~/dotfiles#amisa@wsl
```

## Add a new host

Duplicate a block under `homeConfigurations` in `flake.nix` with the right
`system` / `username` / `homeDirectory`, then run the apply command with the
new name.
