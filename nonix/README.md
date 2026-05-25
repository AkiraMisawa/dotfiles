# nonix — company WSL setup without Nix

The Nix + home-manager setup in the repo root can't run on the company WSL
machine. This directory reproduces the same environment the no-Nix way:

- **apt** for the shell (`zsh`), system deps, and the CLIs Ubuntu packages well
  (`ripgrep`, `fd`, `bat`, `fzf`, `micro`, plus the yazi preview helpers).
- **pinned GitHub-release binaries** in `~/.local/bin` for everything Ubuntu
  ships too old or not at all (helix, yazi, eza, zellij, delta, gh, lazygit,
  gitui, zoxide, just, yq, moar, starship, marksman). Versions are pinned at the top
  of [`bootstrap.sh`](./bootstrap.sh) — bump there and re-run to upgrade.
- **plain symlinks** for config (zshrc, gitconfig, gitui, helix, yazi, micro) and a
  hand-written `~/.zshrc` reproducing what home-manager used to generate.

No `mise`, no extra apt repositories — just apt and direct downloads, which is
the most reliable thing behind a locked-down corporate proxy.

It coexists with the Nix setup on `main`; nothing here touches `flake.nix`,
`home.nix`, or the root `bootstrap.sh`. Static assets in `../files/`
(`p10k.zsh`, micro themes, the yazi plugin, the Claude statusline) are shared
by symlink, not duplicated.

## Setup

```sh
git clone git@github.com:AkiraMisawa/dotfiles ~/dotfiles
cd ~/dotfiles
cp nonix/env.local.example nonix/env.local   # then edit (see below)
bash nonix/bootstrap.sh
```

`bootstrap.sh` is idempotent — each step detects "already done" and skips
(binaries via a version marker under `~/.local/state/dotfiles-nonix/`), so
re-running after a failure is safe. On the first run with no `env.local` it
creates one from the example and stops so you can fill it in.

If the script breaks, [`MANUAL.md`](./MANUAL.md) has every step as
copy-paste-able commands to run by hand.

## env.local (gitignored)

Site-specific values live in `nonix/env.local`, never in the repo. See
[`env.local.example`](./env.local.example):

| Variable            | Purpose                                                        |
|---------------------|----------------------------------------------------------------|
| `http_proxy` etc.   | Corporate proxy. Exported for apt, git, curl, gh.              |
| `CORP_CA_PEM`       | Path to the company root CA → installed into the system store. |
| `GIT_COMPANY_EMAIL` | Work git email → written to `~/.gitconfig.local`.              |
| `INSTALL_EMACS=1`   | Optional: also `apt install emacs-nox`.                        |

## Proxy / corporate CA — the important part

The binary downloads come from `github.com` (releases) and
`objects.githubusercontent.com`. Behind a TLS-intercepting proxy `curl` fails
with cert errors until the company root CA is trusted by the **system** store.
`bootstrap.sh` handles this when `CORP_CA_PEM` is set:

```sh
sudo cp "$CORP_CA_PEM" /usr/local/share/ca-certificates/corp-dotfiles.crt
sudo update-ca-certificates
```

`~/.zshrc` also exports `SSL_CERT_FILE` / `NODE_EXTRA_CA_CERTS` pointing at the
system bundle, for node-based tools and Claude Code. `curl` and `apt` both read
the proxy from the environment / `/etc/apt/apt.conf.d/95dotfiles-proxy` that
the script writes.

## What maps to what

| home.nix                              | nonix equivalent                          |
|---------------------------------------|-------------------------------------------|
| `home.packages` — rg/fd/bat/fzf/micro | apt packages                              |
| `home.packages` — the rest of the CLIs| pinned binaries in `~/.local/bin`         |
| yazi preview helpers, rsync           | apt packages                              |
| emacs                                 | apt `emacs-nox` (opt-in via `INSTALL_EMACS`) |
| `nil` (Nix LSP)                       | dropped (no Nix)                          |
| `yaml-language-server`                | omitted by default (npm-only — see below) |
| `programs.zsh` (generated zshrc)      | hand-written `zsh/zshrc`                  |
| `programs.git` + `programs.delta`     | `git/gitconfig` (+ `~/.gitconfig.local`)  |
| `programs.helix`                      | `helix/config.toml` (+ bundled runtime)   |
| `programs.yazi`                       | `yazi/keymap.toml` + shared plugin        |
| micro `xdg.configFile`                | symlinks + settings.json merge            |
| Claude statusline activation          | symlink + settings.json merge             |
| Nix-store zsh + `chsh`                | apt `zsh` (`/usr/bin/zsh`) + `chsh`       |

### Binary-name notes

- Ubuntu installs **fd** as `fdfind` and **bat** as `batcat`; the script
  symlinks the usual names into `~/.local/bin`.
- The pager formerly called `moar` is now upstream-named `moor`; we install its
  binary as `moar` and set `PAGER=moar` for consistency.
- **helix** needs its `runtime/` (themes incl. tokyonight, tree-sitter
  grammars). The script extracts it to `~/.config/helix/runtime`, where `hx`
  finds it automatically.

## Updating tools

- **apt-managed** CLIs: `sudo apt upgrade`.
- **pinned binaries**: edit the `V_*` versions at the top of `bootstrap.sh`,
  then re-run it — a changed pin invalidates the marker and reinstalls.

## Optional: yaml-language-server

It's distributed only via npm, so it needs Node. If you want YAML LSP in helix:

```sh
sudo apt-get install -y nodejs npm
npm config set proxy "$http_proxy"; npm config set https-proxy "$https_proxy"
npm install -g yaml-language-server
```
