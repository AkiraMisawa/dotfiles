#!/usr/bin/env bash
# Bootstrap a new machine for this dotfiles repo. Idempotent — safe to re-run.
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/AkiraMisawa/dotfiles/main/bootstrap.sh)

set -euo pipefail

REPO_URL="git@github.com:AkiraMisawa/dotfiles.git"
DOTFILES_DIR="${HOME}/dotfiles"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33m--\033[0m %s (skip)\n' "$*"; }

# --- Detect platform → home-manager flake target -----------------------------
case "$(uname -s)" in
  Darwin)
    HOST="misamisa@mac"
    ;;
  Linux)
    if grep -qiE 'microsoft|wsl' /proc/version 2>/dev/null; then
      HOST="akira@wsl"
    else
      echo "Unsupported Linux (not WSL). Add a homeConfigurations entry first." >&2
      exit 1
    fi
    ;;
  *)
    echo "Unsupported platform: $(uname -s)" >&2
    exit 1
    ;;
esac
log "Target host: ${HOST}"

# --- Install Nix if missing --------------------------------------------------
if command -v nix >/dev/null 2>&1; then
  skip "Nix already installed: $(nix --version)"
else
  log "Installing Nix (Determinate Systems installer)..."
  curl --proto '=https' --tlsv1.2 -sSf -L \
    https://install.determinate.systems/nix | sh -s -- install
  for f in \
    /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
    "${HOME}/.nix-profile/etc/profile.d/nix.sh"; do
    if [[ -f "${f}" ]]; then
      # shellcheck disable=SC1090
      . "${f}"
      break
    fi
  done
fi

# --- GitHub auth + SSH key registration --------------------------------------
# `gh auth login -p ssh -w` generates an ed25519 key (if missing), uploads the
# public key to GitHub, and sets git's default protocol to SSH — all in one.
if nix run nixpkgs#gh -- auth status >/dev/null 2>&1; then
  skip "gh already authenticated"
else
  log "Authenticating with GitHub (will generate + upload SSH key)..."
  nix run nixpkgs#gh -- auth login \
    --hostname github.com \
    --git-protocol ssh \
    --web
fi

# --- Clone dotfiles ----------------------------------------------------------
if [[ -d "${DOTFILES_DIR}/.git" ]]; then
  skip "${DOTFILES_DIR} already a git repo"
else
  log "Cloning ${REPO_URL} → ${DOTFILES_DIR}"
  git clone "${REPO_URL}" "${DOTFILES_DIR}"
fi

# --- Apply home-manager ------------------------------------------------------
log "Applying home-manager (.#${HOST})..."
cd "${DOTFILES_DIR}"
nix run home-manager/master -- switch --flake ".#${HOST}" -b backup

# --- Switch login shell to zsh (Linux only; macOS defaults to zsh already) ---
if [[ "$(uname -s)" == "Linux" ]]; then
  zsh_path="${HOME}/.nix-profile/bin/zsh"
  if [[ ! -x "${zsh_path}" ]]; then
    echo "Warning: ${zsh_path} not found — home-manager switch may have failed." >&2
  else
    if grep -qxF "${zsh_path}" /etc/shells 2>/dev/null; then
      skip "${zsh_path} already in /etc/shells"
    else
      log "Adding ${zsh_path} to /etc/shells (sudo)..."
      echo "${zsh_path}" | sudo tee -a /etc/shells >/dev/null
    fi
    current_shell=""
    if command -v getent >/dev/null 2>&1; then
      current_shell="$(getent passwd "${USER}" | cut -d: -f7)"
    fi
    if [[ "${current_shell}" == "${zsh_path}" ]]; then
      skip "Login shell already ${zsh_path}"
    else
      log "Changing login shell to ${zsh_path}..."
      chsh -s "${zsh_path}"
    fi
  fi
fi

log "Done. Open a new shell to pick up the new environment."
