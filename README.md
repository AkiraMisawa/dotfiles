# dotfiles

Cross-platform dotfiles managed with [Nix flakes](https://nixos.wiki/wiki/Flakes)
and [home-manager](https://github.com/nix-community/home-manager).

Sets up zsh (powerlevel10k, autosuggestion, syntax highlighting), git + delta,
gh, lazygit, helix, direnv (nix-direnv), zoxide, fzf, yazi, eza, starship, and
a CLI toolchain (ripgrep, fd, jq, bat, just, micro, rsync, yq, zellij, emacs,
plus yazi preview helpers).

## New-machine setup

A fresh machine almost never has `nix` installed, so step 1 is the
prerequisite — without it nothing else works.

### 1. Install Nix (with flakes enabled)

The [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer)
is the easiest path. It works on Linux (including WSL) and macOS, and enables
flakes by default:

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

Start a new shell so `nix` is on `PATH`, then verify:

```sh
nix --version
nix flake --help >/dev/null   # must not error
```

If you used the upstream installer instead, enable flakes manually:

```sh
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
```

### 2. Clone this repo

`git` ships on most distros; if not, `nix-shell -p git` works once Nix is
installed.

```sh
git clone https://github.com/AkiraMisawa/dotfiles ~/dotfiles
cd ~/dotfiles
```

### 3. Apply with home-manager

Pick the host config from `flake.nix` (currently `amisa@wsl`). The first run
does not need home-manager pre-installed — `nix run` fetches it on demand:

```sh
nix run home-manager/master -- switch --flake .#amisa@wsl -b backup
```

`-b backup` renames any pre-existing dotfile that would be overwritten to
`*.backup` instead of aborting. Useful on a machine that already has hand-rolled
config you want to keep around.

After the first switch, `home-manager` is on `PATH`:

```sh
home-manager switch --flake ~/dotfiles#amisa@wsl
```

### 4. Switch login shell to zsh

home-manager installs zsh but does not change the login shell. On Linux:

```sh
chsh -s "$(command -v zsh)"
```

On WSL you may also need to add the path to `/etc/shells` first if `chsh`
complains:

```sh
command -v zsh | sudo tee -a /etc/shells
```

Open a new session to pick up the new shell.

## Adding a new host

Duplicate a block under `homeConfigurations` in `flake.nix` with the right
`system`, `username`, and `homeDirectory`, then run the apply command with the
new name.

| Target              | `system`         | `homeDirectory`  |
|---------------------|------------------|------------------|
| WSL / Linux x86_64  | `x86_64-linux`   | `/home/<user>`   |
| Linux ARM           | `aarch64-linux`  | `/home/<user>`   |
| Apple Silicon macOS | `aarch64-darwin` | `/Users/<user>`  |
| Intel macOS         | `x86_64-darwin`  | `/Users/<user>`  |

On macOS, this setup manages user-level config only. For system-level macOS
settings (defaults, launchd, Homebrew bridging) use
[nix-darwin](https://github.com/LnL7/nix-darwin); not included here.

## Updating

```sh
cd ~/dotfiles
nix flake update                                  # bump nixpkgs / home-manager
home-manager switch --flake .#amisa@wsl
```

Roll back if a switch broke something:

```sh
home-manager generations
home-manager rollback
```

## Layout

```
flake.nix     # inputs (nixpkgs, home-manager) and per-host configurations
home.nix      # user environment: packages, programs, zsh, git, ...
files/        # static assets sourced from home.nix (e.g. p10k.zsh)
```
