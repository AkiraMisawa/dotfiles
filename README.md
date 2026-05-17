# dotfiles

Cross-platform dotfiles managed with [Nix flakes](https://nixos.wiki/wiki/Flakes)
and [home-manager](https://github.com/nix-community/home-manager).

Sets up zsh (powerlevel10k, autosuggestion, syntax highlighting), git + delta,
gh, lazygit, helix, direnv (nix-direnv), zoxide, fzf, yazi, eza, starship, and
a CLI toolchain (ripgrep, fd, jq, bat, just, micro, rsync, yq, zellij, emacs,
plus yazi preview helpers).

## New-machine setup

One command does everything — Nix install, GitHub auth + SSH key registration,
clone, home-manager switch, (on Linux) login-shell change, and Claude Code
install:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/AkiraMisawa/dotfiles/main/bootstrap.sh)
```

`bash <(curl ...)` (not `curl ... | bash`) keeps stdin attached to the
terminal, which the interactive `gh auth login --web` prompt needs.

The script ([`bootstrap.sh`](./bootstrap.sh)) is idempotent — each step
detects "already done" and skips, so re-running after a failure is safe.
It picks the right `homeConfigurations` entry from `uname -s` /
`/proc/version`: Darwin → `misamisa@mac`, WSL → `akira@wsl`.

### Manual fallback

If something in `bootstrap.sh` breaks, run the steps by hand.

#### 1. Install Nix (with flakes enabled)

The [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer)
works on Linux (including WSL) and macOS, and enables flakes by default:

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

#### 2. Authenticate with GitHub (generates + uploads SSH key)

```sh
nix run nixpkgs#gh -- auth login --hostname github.com --git-protocol ssh --web
```

This single command generates an ed25519 key (if missing), uploads the
public key to GitHub, and sets git's default protocol to SSH.

#### 3. Clone this repo

```sh
git clone git@github.com:AkiraMisawa/dotfiles ~/dotfiles
cd ~/dotfiles
```

#### 4. Apply with home-manager

Pick the entry under `homeConfigurations` in `flake.nix` matching the
machine. The first run does not need home-manager pre-installed —
`nix run` fetches it on demand:

| Machine               | First run (no home-manager on PATH)                                                | Subsequent runs                                            |
|-----------------------|------------------------------------------------------------------------------------|------------------------------------------------------------|
| WSL (OS user `akira`) | `nix run home-manager/master -- switch --flake .#akira@wsl -b backup`              | `home-manager switch --flake ~/dotfiles#akira@wsl`         |
| macOS (OS user `misamisa`) | `nix run home-manager/master -- switch --flake .#misamisa@mac -b backup`      | `home-manager switch --flake ~/dotfiles#misamisa@mac`      |

`-b backup` renames any pre-existing dotfile that would be overwritten to
`*.backup` instead of aborting. This is how a Mac with existing `gnu stow`
symlinks gets migrated cleanly: stow's symlinks become `*.backup`, the
stow source tree is untouched, and `stow -D` can clean up afterward.

#### 5. Switch login shell to zsh (Linux only)

home-manager installs zsh but does not change the login shell. macOS
already ships zsh as the default, so this step only applies on Linux.

The zsh installed by home-manager lives at `~/.nix-profile/bin/zsh`,
not at the system `/usr/bin/zsh` (Ubuntu does not ship zsh). `chsh`
requires the target shell to be listed in `/etc/shells`, so add it
first:

```sh
echo "$HOME/.nix-profile/bin/zsh" | sudo tee -a /etc/shells
chsh -s "$HOME/.nix-profile/bin/zsh"
```

Open a new session to pick up the new shell.

#### 6. Install Claude Code

Claude Code is intentionally not managed by Nix — its built-in
auto-update conflicts with read-only `/nix/store` binaries. The
official installer drops the binary at `~/.local/bin/claude`, which
`home.sessionPath` already exposes:

```sh
curl -fsSL https://claude.ai/install.sh | bash
```

Auto-updates run in the background. Run `claude` in any project to
authenticate on first use.

## Adding a new host

Each entry under `homeConfigurations` in `flake.nix` is keyed by
`<OS-user>@<host>` and pins the `(system, username, homeDirectory)`
tuple plus git identity. Reuse an existing entry on any machine whose
tuple matches it; add a new one only when you have a new tuple (e.g.
a different OS user, or a work-account git identity).

```nix
"newuser@laptop" = mkHome {
  system = "aarch64-darwin";
  username = "newuser";
  homeDirectory = "/Users/newuser";
  gitName  = "Real Name";
  gitEmail = "you@example.com";
};
```

Apply with `home-manager switch --flake .#newuser@laptop`.

| Target              | `system`         | `homeDirectory`     |
|---------------------|------------------|---------------------|
| WSL / Linux x86_64  | `x86_64-linux`   | `/home/<user>`      |
| Linux ARM           | `aarch64-linux`  | `/home/<user>`      |
| Apple Silicon macOS | `aarch64-darwin` | `/Users/<user>`     |
| Intel macOS         | `x86_64-darwin`  | `/Users/<user>`     |

On macOS, this setup manages user-level config only. For system-level macOS
settings (defaults, launchd, Homebrew bridging) use
[nix-darwin](https://github.com/LnL7/nix-darwin); not included here.

## Updating

```sh
cd ~/dotfiles
nix flake update                                  # bump nixpkgs / home-manager
home-manager switch --flake .#akira@wsl           # or .#misamisa@mac on Mac
```

Roll back if a switch broke something:

```sh
home-manager generations
home-manager rollback
```

## Layout

```
bootstrap.sh  # one-shot new-machine installer (fetched via curl from raw URL)
flake.nix     # inputs (nixpkgs, home-manager) and per-host configurations
home.nix      # user environment: packages, programs, zsh, git, ...
files/        # static assets sourced from home.nix (e.g. p10k.zsh)
```
