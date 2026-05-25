# Manual setup (no-Nix, company WSL)

Fallback for when [`bootstrap.sh`](./bootstrap.sh) breaks. Run these by hand,
top to bottom. Same end state as the script. Assumes the repo is at
`~/dotfiles` — adjust `DOT` below if not.

```sh
DOT=~/dotfiles            # repo root
NONIX=$DOT/nonix
FILES=$DOT/files
```

## 0. Site-specific values

Set these for your environment (or `source nonix/env.local` if you filled it
in). Skip the proxy lines if you are not behind one.

```sh
export http_proxy="http://proxy.corp.example:8080"
export https_proxy="$http_proxy"
export all_proxy="$http_proxy"
export no_proxy="localhost,127.0.0.1,::1,.corp.example"
export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
export ALL_PROXY="$all_proxy" NO_PROXY="$no_proxy"

CORP_CA_PEM="$HOME/corp-root-ca.pem"   # company root CA (PEM), or leave empty
GIT_COMPANY_EMAIL="you@company.example"
```

## 1. Corporate CA → system trust store

Skip if your proxy does not intercept TLS. Without this, mise downloads fail
with `invalid peer certificate: UnknownIssuer`.

```sh
sudo cp "$CORP_CA_PEM" /usr/local/share/ca-certificates/corp-dotfiles.crt
sudo update-ca-certificates
```

## 2. apt: shell + heavy/system deps

If `sudo` drops your proxy env, either use `sudo -E ...` (as below) or write
`/etc/apt/apt.conf.d/95proxy` with `Acquire::https::Proxy "...";`.

CLIs Ubuntu packages well go in via apt; `fd`/`bat` install under alternate
names, so we symlink the usual ones afterwards.

```sh
mkdir -p ~/.local/bin
sudo -E apt-get update -y
sudo -E apt-get install -y \
  zsh git curl ca-certificates jq rsync tar xz-utils unzip \
  ripgrep fd-find bat micro fzf \
  ffmpegthumbnailer poppler-utils imagemagick p7zip-full chafa unar
# optional: sudo -E apt-get install -y emacs-nox

ln -sfn "$(command -v fdfind)" ~/.local/bin/fd
ln -sfn "$(command -v batcat)" ~/.local/bin/bat
```

## 3. Install the rest as pinned binaries → ~/.local/bin

Ubuntu ships these too old or not at all. Versions below match the pins in
`bootstrap.sh` — bump them together. `curl` uses your proxy from the
environment.

```sh
GH=https://github.com
b=~/.local/bin; mkdir -p "$b"

# tarball/zip downloads — extract, then move the binary into ~/.local/bin
get() {  # get <url> <binname-in-archive> <install-as>
  local url=$1 name=$2 as=$3 tmp; tmp=$(mktemp -d)
  curl -fSL --retry 3 -o "$tmp/a" "$url"
  case "$url" in
    *.tar.gz) tar -xzf "$tmp/a" -C "$tmp" ;;
    *.tar.xz) tar -xJf "$tmp/a" -C "$tmp" ;;
    *.zip)    unzip -q "$tmp/a" -d "$tmp" ;;
  esac
  install -m755 "$(find "$tmp" -type f -name "$name" | head -1)" "$b/$as"
  rm -rf "$tmp"
}

get "$GH/dandavison/delta/releases/download/0.19.2/delta-0.19.2-x86_64-unknown-linux-musl.tar.gz" delta delta
get "$GH/cli/cli/releases/download/v2.92.0/gh_2.92.0_linux_amd64.tar.gz" gh gh
get "$GH/jesseduffield/lazygit/releases/download/v0.61.1/lazygit_0.61.1_linux_x86_64.tar.gz" lazygit lazygit
get "$GH/gitui-org/gitui/releases/download/v0.28.1/gitui-linux-x86_64.tar.gz" gitui gitui
get "$GH/ajeetdsouza/zoxide/releases/download/v0.9.9/zoxide-0.9.9-x86_64-unknown-linux-musl.tar.gz" zoxide zoxide
get "$GH/eza-community/eza/releases/download/v0.23.4/eza_x86_64-unknown-linux-musl.tar.gz" eza eza
get "$GH/starship/starship/releases/download/v1.25.1/starship-x86_64-unknown-linux-musl.tar.gz" starship starship
get "$GH/zellij-org/zellij/releases/download/v0.44.3/zellij-x86_64-unknown-linux-musl.tar.gz" zellij zellij
get "$GH/casey/just/releases/download/1.51.0/just-1.51.0-x86_64-unknown-linux-musl.tar.gz" just just
get "$GH/sxyazi/yazi/releases/download/v26.5.6/yazi-x86_64-unknown-linux-musl.zip" yazi yazi
get "$GH/sxyazi/yazi/releases/download/v26.5.6/yazi-x86_64-unknown-linux-musl.zip" ya ya

# single raw binaries
curl -fSL -o "$b/yq"       "$GH/mikefarah/yq/releases/download/v4.53.2/yq_linux_amd64"
curl -fSL -o "$b/moar"     "$GH/walles/moar/releases/download/v2.13.2/moor-v2.13.2-linux-amd64"
curl -fSL -o "$b/marksman" "$GH/artempyanykh/marksman/releases/download/2026-02-08/marksman-linux-x64"
chmod +x "$b/yq" "$b/moar" "$b/marksman"

# helix needs its bundled runtime/ (themes + grammars)
tmp=$(mktemp -d)
curl -fSL -o "$tmp/hx.tar.xz" "$GH/helix-editor/helix/releases/download/25.07.1/helix-25.07.1-x86_64-linux.tar.xz"
tar -xJf "$tmp/hx.tar.xz" -C "$tmp"
install -m755 "$tmp/helix-25.07.1-x86_64-linux/hx" "$b/hx"
mkdir -p ~/.config/helix && rm -rf ~/.config/helix/runtime
cp -r "$tmp/helix-25.07.1-x86_64-linux/runtime" ~/.config/helix/runtime
rm -rf "$tmp"
```

(`yaml-language-server` is npm-only; see the README if you want it.)

## 5. Clone zsh plugins

```sh
P=~/.local/share/zsh/plugins
mkdir -p "$P"
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git              "$P/powerlevel10k"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git      "$P/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git  "$P/zsh-syntax-highlighting"
git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search.git "$P/zsh-history-substring-search"
```

## 6. Symlink configs

```sh
# zsh + p10k
ln -sfn "$NONIX/zsh/zshrc"  ~/.zshrc
ln -sfn "$FILES/p10k.zsh"   ~/.p10k.zsh

# git (delta + settings); company email goes in a separate, uncommitted file
ln -sfn "$NONIX/git/gitconfig" ~/.gitconfig
printf '[user]\n\temail = %s\n' "$GIT_COMPANY_EMAIL" > ~/.gitconfig.local

# helix
mkdir -p ~/.config/helix
ln -sfn "$NONIX/helix/config.toml" ~/.config/helix/config.toml

# yazi (keymap + the copy-across-tabs plugin)
mkdir -p ~/.config/yazi/plugins
ln -sfn "$NONIX/yazi/keymap.toml" ~/.config/yazi/keymap.toml
ln -sfn "$FILES/yazi-plugins/copy-across-tabs" ~/.config/yazi/plugins/copy-across-tabs

# micro (colorscheme + syntax + settings)
mkdir -p ~/.config/micro/colorschemes ~/.config/micro/syntax
ln -sfn "$FILES/micro-tokyonight.micro" ~/.config/micro/colorschemes/tokyonight.micro
ln -sfn "$FILES/micro-markdown.yaml"    ~/.config/micro/syntax/markdown.yaml
[ -s ~/.config/micro/settings.json ] || echo '{}' > ~/.config/micro/settings.json
tmp=$(mktemp); jq '. + {colorscheme:"tokyonight"}' ~/.config/micro/settings.json > "$tmp" && mv "$tmp" ~/.config/micro/settings.json
```

## 7. Claude Code statusline

```sh
mkdir -p ~/.claude
ln -sfn "$FILES/claude-statusline.sh" ~/.claude/statusline.sh
chmod +x "$FILES/claude-statusline.sh"
[ -s ~/.claude/settings.json ] || echo '{}' > ~/.claude/settings.json
tmp=$(mktemp)
jq '. + {statusLine:{type:"command",command:"~/.claude/statusline.sh",padding:1}}' \
  ~/.claude/settings.json > "$tmp" && mv "$tmp" ~/.claude/settings.json
```

## 8. Change login shell to zsh

```sh
zsh_path="$(command -v zsh)"                 # /usr/bin/zsh
grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
chsh -s "$zsh_path"
```

## 9. Install Claude Code

```sh
curl -fsSL https://claude.ai/install.sh | bash
```

## 10. Verify

Open a **new** shell, then:

```sh
for t in rg fd fzf bat hx yazi delta gh lazygit gitui zellij just eza zoxide starship moar marksman; do
  command -v "$t" >/dev/null && echo "ok  $t" || echo "MISSING $t"
done
git config --list | grep -E 'user\.|pager|rerere'   # delta + your email
hx --health >/dev/null && echo "helix ok"
```

You should see the p10k prompt, working autosuggestions, `cd <substr>` jumping
via zoxide, `y` opening yazi, and `rgo <pattern>` opening matches in helix.

## Troubleshooting

- **Cert errors (`SSL certificate problem` / `unable to get local issuer`)
  during a `curl` download** — the corporate CA isn't trusted. Redo step 1,
  confirm with `openssl s_client -connect github.com:443 </dev/null` (look for
  `Verify return code: 0`).
- **A download 404s** — the pinned version was bumped/yanked. Check the latest
  tag on the project's GitHub releases page and update the URL/version.
- **`hx` has no themes / `Theme not found`** — the runtime didn't land; redo
  the helix block in step 3 (it must populate `~/.config/helix/runtime`).
- **`chsh` rejected** — the shell must be listed in `/etc/shells` (step 8).
- **No icons in `ls`/p10k** — install a Nerd Font on the Windows side and set
  it as the WSL terminal font.
