#!/usr/bin/env bash
# Bootstrap a company WSL machine WITHOUT Nix. Idempotent — safe to re-run.
# The no-Nix counterpart to ../bootstrap.sh:
#   - apt for the shell, system deps, and CLIs Ubuntu packages well
#   - pinned GitHub-release binaries in ~/.local/bin for the rest
#   - plain symlinks for config
#
# Usage (after cloning the repo):
#   cp nonix/env.local.example nonix/env.local   # then edit it
#   bash nonix/bootstrap.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
FILES_DIR="$REPO_DIR/files"
ENV_LOCAL="$SCRIPT_DIR/env.local"

BIN="$HOME/.local/bin"
VSTATE="$HOME/.local/state/dotfiles-nonix/versions"   # installed-version markers

# --- Pinned tool versions (bump here, then re-run) ---------------------------
V_DELTA=0.19.2
V_GH=2.92.0
V_LAZYGIT=0.61.1
V_GITUI=0.28.1
V_ZOXIDE=0.9.9
V_EZA=0.23.4
V_STARSHIP=1.25.1
V_HELIX=25.07.1
V_YAZI=26.5.6
V_ZELLIJ=0.44.3
V_JUST=1.51.0
V_YQ=4.53.2
V_MOAR=2.13.2          # upstream binary is now named "moor"; we install it as "moar"
V_MARKSMAN=2026-02-08

GH=https://github.com

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m--\033[0m %s (skip)\n' "$*"; }
warn() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; }

# Symlink $1 -> $2, creating parent dirs. Idempotent.
link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    skip "$dest already linked"
  else
    ln -sfn "$src" "$dest"
    log "linked $dest -> $src"
  fi
}

# Shallow-clone $1 into $2 if not already a git repo. Idempotent.
clone() {
  if [[ -d "$2/.git" ]]; then
    skip "$(basename "$2") already cloned"
  else
    log "cloning $(basename "$2")..."
    git clone --depth=1 "$1" "$2"
  fi
}

# Merge a JSON fragment into a JSON file, creating it if needed.
json_merge() {
  local file="$1" filter="$2" tmp
  mkdir -p "$(dirname "$file")"
  [[ -s "$file" ]] || echo '{}' > "$file"
  tmp="$(mktemp)"
  jq "$filter" "$file" > "$tmp" && mv "$tmp" "$file"
}

# --- binary-install helpers --------------------------------------------------
# A tool is "current" iff its binary exists and its version marker matches.
current() { [[ -x "$BIN/$1" && "$(cat "$VSTATE/$1" 2>/dev/null)" == "$2" ]]; }
mark()    { echo "$2" > "$VSTATE/$1"; }
fetch()   { curl -fSL --retry 3 -o "$2" "$1"; }

# install_archive <name> <version> <url> [<binname-in-archive>]
# Downloads an archive (.tar.gz/.tar.xz/.zip), finds the named binary, installs.
install_archive() {
  local name=$1 ver=$2 url=$3 bin=${4:-$1}
  current "$name" "$ver" && { skip "$name $ver"; return; }
  log "installing $name $ver"
  local tmp found; tmp=$(mktemp -d)
  fetch "$url" "$tmp/dl"
  case "$url" in
    *.tar.gz|*.tgz) tar -xzf "$tmp/dl" -C "$tmp" ;;
    *.tar.xz)       tar -xJf "$tmp/dl" -C "$tmp" ;;
    *.zip)          unzip -q "$tmp/dl" -d "$tmp" ;;
    *) warn "unknown archive type: $url"; rm -rf "$tmp"; return 1 ;;
  esac
  found=$(find "$tmp" -type f -name "$bin" | head -1)
  [[ -n "$found" ]] || { warn "$bin not found inside $url"; rm -rf "$tmp"; return 1; }
  install -m755 "$found" "$BIN/$name"
  mark "$name" "$ver"
  rm -rf "$tmp"
}

# install_single <name> <version> <url>  — a single raw binary asset.
install_single() {
  local name=$1 ver=$2 url=$3
  current "$name" "$ver" && { skip "$name $ver"; return; }
  log "installing $name $ver"
  fetch "$url" "$BIN/$name"
  chmod 755 "$BIN/$name"
  mark "$name" "$ver"
}

# helix ships its runtime/ (themes, grammars) alongside the binary.
install_helix() {
  current hx "$V_HELIX" && { skip "helix $V_HELIX"; return; }
  log "installing helix $V_HELIX"
  local tmp src; tmp=$(mktemp -d)
  fetch "$GH/helix-editor/helix/releases/download/${V_HELIX}/helix-${V_HELIX}-x86_64-linux.tar.xz" "$tmp/hx.tar.xz"
  tar -xJf "$tmp/hx.tar.xz" -C "$tmp"
  src="$tmp/helix-${V_HELIX}-x86_64-linux"
  install -m755 "$src/hx" "$BIN/hx"
  mkdir -p "$HOME/.config/helix"
  rm -rf "$HOME/.config/helix/runtime"
  cp -r "$src/runtime" "$HOME/.config/helix/runtime"   # hx finds this automatically
  mark hx "$V_HELIX"
  rm -rf "$tmp"
}

# yazi ships two binaries (yazi + ya) in one zip.
install_yazi() {
  if current yazi "$V_YAZI" && current ya "$V_YAZI"; then skip "yazi $V_YAZI"; return; fi
  log "installing yazi $V_YAZI"
  local tmp; tmp=$(mktemp -d)
  fetch "$GH/sxyazi/yazi/releases/download/v${V_YAZI}/yazi-x86_64-unknown-linux-musl.zip" "$tmp/y.zip"
  unzip -q "$tmp/y.zip" -d "$tmp"
  install -m755 "$(find "$tmp" -type f -name yazi | head -1)" "$BIN/yazi"
  install -m755 "$(find "$tmp" -type f -name ya   | head -1)" "$BIN/ya"
  mark yazi "$V_YAZI"; mark ya "$V_YAZI"
  rm -rf "$tmp"
}

# --- 1. WSL check ------------------------------------------------------------
if ! grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
  warn "This script targets WSL. Aborting on non-WSL Linux."
  exit 1
fi
if [[ "$(uname -m)" != "x86_64" ]]; then
  warn "Only x86_64 is supported (got $(uname -m)). Adjust the asset URLs first."
  exit 1
fi

# --- 2. Load site-specific env ----------------------------------------------
if [[ ! -f "$ENV_LOCAL" ]]; then
  cp "$SCRIPT_DIR/env.local.example" "$ENV_LOCAL"
  warn "Created $ENV_LOCAL from the example."
  warn "Edit it (proxy, corporate CA, company git email), then re-run."
  exit 1
fi
# shellcheck disable=SC1090
source "$ENV_LOCAL"
log "Loaded $ENV_LOCAL"

# --- 3. Proxy + corporate CA -------------------------------------------------
if [[ -n "${http_proxy:-}" ]]; then
  log "Proxy: ${http_proxy}"
  printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' \
    "$http_proxy" "${https_proxy:-$http_proxy}" \
    | sudo tee /etc/apt/apt.conf.d/95dotfiles-proxy >/dev/null
else
  skip "No http_proxy set"
fi

if [[ -n "${CORP_CA_PEM:-}" && -f "$CORP_CA_PEM" ]]; then
  ca_dest=/usr/local/share/ca-certificates/corp-dotfiles.crt
  if sudo cmp -s "$CORP_CA_PEM" "$ca_dest" 2>/dev/null; then
    skip "Corporate CA already installed"
  else
    log "Installing corporate CA into system trust store..."
    sudo cp "$CORP_CA_PEM" "$ca_dest"
    sudo update-ca-certificates
  fi
elif [[ -n "${CORP_CA_PEM:-}" ]]; then
  warn "CORP_CA_PEM=$CORP_CA_PEM not found — skipping CA install."
fi

mkdir -p "$BIN" "$VSTATE"

# --- 4. apt: shell, system deps, and well-packaged CLIs ----------------------
log "Installing apt packages (sudo)..."
sudo -E apt-get update -y
sudo -E apt-get install -y \
  zsh git curl ca-certificates jq rsync tar xz-utils unzip \
  ripgrep fd-find bat micro fzf \
  ffmpegthumbnailer poppler-utils imagemagick p7zip-full chafa unar
if [[ "${INSTALL_EMACS:-0}" == "1" ]]; then
  sudo -E apt-get install -y emacs-nox
fi

# Debian/Ubuntu install these under alternate names; expose the usual names.
fdbin="$(command -v fdfind || true)"; [[ -n "$fdbin" ]] && link "$fdbin" "$BIN/fd"
batbin="$(command -v batcat || true)"; [[ -n "$batbin" ]] && link "$batbin" "$BIN/bat"

# --- 5. Pinned GitHub-release binaries → ~/.local/bin ------------------------
install_archive delta    "$V_DELTA"    "$GH/dandavison/delta/releases/download/${V_DELTA}/delta-${V_DELTA}-x86_64-unknown-linux-musl.tar.gz"
install_archive gh       "$V_GH"       "$GH/cli/cli/releases/download/v${V_GH}/gh_${V_GH}_linux_amd64.tar.gz"
install_archive lazygit  "$V_LAZYGIT"  "$GH/jesseduffield/lazygit/releases/download/v${V_LAZYGIT}/lazygit_${V_LAZYGIT}_linux_x86_64.tar.gz"
install_archive gitui    "$V_GITUI"    "$GH/gitui-org/gitui/releases/download/v${V_GITUI}/gitui-linux-x86_64.tar.gz"
install_archive zoxide   "$V_ZOXIDE"   "$GH/ajeetdsouza/zoxide/releases/download/v${V_ZOXIDE}/zoxide-${V_ZOXIDE}-x86_64-unknown-linux-musl.tar.gz"
install_archive eza      "$V_EZA"      "$GH/eza-community/eza/releases/download/v${V_EZA}/eza_x86_64-unknown-linux-musl.tar.gz"
install_archive starship "$V_STARSHIP" "$GH/starship/starship/releases/download/v${V_STARSHIP}/starship-x86_64-unknown-linux-musl.tar.gz"
install_archive zellij   "$V_ZELLIJ"   "$GH/zellij-org/zellij/releases/download/v${V_ZELLIJ}/zellij-x86_64-unknown-linux-musl.tar.gz"
install_archive just     "$V_JUST"     "$GH/casey/just/releases/download/${V_JUST}/just-${V_JUST}-x86_64-unknown-linux-musl.tar.gz"
install_single  yq       "$V_YQ"       "$GH/mikefarah/yq/releases/download/v${V_YQ}/yq_linux_amd64"
install_single  moar     "$V_MOAR"     "$GH/walles/moar/releases/download/v${V_MOAR}/moor-v${V_MOAR}-linux-amd64"
install_single  marksman "$V_MARKSMAN" "$GH/artempyanykh/marksman/releases/download/${V_MARKSMAN}/marksman-linux-x64"
install_helix
install_yazi
# Note: yaml-language-server is npm-only (needs node) — omitted by default.
# See README.md if you want it.

# --- 6. zsh plugins ----------------------------------------------------------
PLUGIN_DIR="$HOME/.local/share/zsh/plugins"
mkdir -p "$PLUGIN_DIR"
clone https://github.com/romkatv/powerlevel10k.git                  "$PLUGIN_DIR/powerlevel10k"
clone https://github.com/zsh-users/zsh-autosuggestions.git          "$PLUGIN_DIR/zsh-autosuggestions"
clone https://github.com/zsh-users/zsh-syntax-highlighting.git      "$PLUGIN_DIR/zsh-syntax-highlighting"
clone https://github.com/zsh-users/zsh-history-substring-search.git "$PLUGIN_DIR/zsh-history-substring-search"

# --- 7. Config symlinks ------------------------------------------------------
link "$SCRIPT_DIR/zsh/zshrc"         "$HOME/.zshrc"
link "$FILES_DIR/p10k.zsh"           "$HOME/.p10k.zsh"
link "$SCRIPT_DIR/git/gitconfig"     "$HOME/.gitconfig"
link "$SCRIPT_DIR/gitui/theme.ron"   "$HOME/.config/gitui/theme.ron"
link "$SCRIPT_DIR/helix/config.toml" "$HOME/.config/helix/config.toml"
link "$SCRIPT_DIR/helix/themes/tokyonight-transparent.toml" \
     "$HOME/.config/helix/themes/tokyonight-transparent.toml"
link "$SCRIPT_DIR/yazi/keymap.toml"  "$HOME/.config/yazi/keymap.toml"
link "$FILES_DIR/yazi-plugins/copy-across-tabs" \
     "$HOME/.config/yazi/plugins/copy-across-tabs"
link "$FILES_DIR/micro-tokyonight.micro" \
     "$HOME/.config/micro/colorschemes/tokyonight.micro"
link "$FILES_DIR/micro-markdown.yaml" \
     "$HOME/.config/micro/syntax/markdown.yaml"
json_merge "$HOME/.config/micro/settings.json" '. + {colorscheme: "tokyonight"}'

# Company git email -> ~/.gitconfig.local (included by the committed gitconfig).
if [[ -n "${GIT_COMPANY_EMAIL:-}" ]]; then
  cat > "$HOME/.gitconfig.local" <<EOF
[user]
	email = ${GIT_COMPANY_EMAIL}
EOF
  log "Wrote git email to ~/.gitconfig.local"
else
  warn "GIT_COMPANY_EMAIL unset — set it in env.local for correct commits."
fi

# Claude Code statusline (script + settings.json merge, == home.nix activation).
link "$FILES_DIR/claude-statusline.sh" "$HOME/.claude/statusline.sh"
chmod +x "$FILES_DIR/claude-statusline.sh"
json_merge "$HOME/.claude/settings.json" \
  '. + {statusLine: {type: "command", command: "~/.claude/statusline.sh", padding: 1}}'

# --- 8. Login shell -> zsh ---------------------------------------------------
zsh_path="$(command -v zsh)"
if ! grep -qxF "$zsh_path" /etc/shells 2>/dev/null; then
  log "Adding $zsh_path to /etc/shells (sudo)..."
  echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
fi
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
if [[ "$current_shell" == "$zsh_path" ]]; then
  skip "Login shell already $zsh_path"
else
  log "Changing login shell to $zsh_path..."
  chsh -s "$zsh_path"
fi

# --- 9. Claude Code ----------------------------------------------------------
if [[ -x "$HOME/.local/bin/claude" ]] || command -v claude >/dev/null 2>&1; then
  skip "claude already installed"
else
  log "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

log "Done. Open a new shell to pick up the new environment."
