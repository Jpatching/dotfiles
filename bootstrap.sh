#!/usr/bin/env bash
# Idempotent dev environment bootstrap for Ubuntu / WSL2.
# Run from inside a cloned copy of this repo: ~/dotfiles/bootstrap.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_REPO="git@github.com:Jpatching/nvim-config.git"

echo "==> Updating apt and installing base packages"
sudo apt-get update -y
sudo apt-get install -y \
  git curl unzip build-essential \
  zsh tmux ripgrep fd-find xclip \
  ca-certificates gnupg

# fd is packaged as fdfind on Ubuntu; symlink to the name LazyVim/telescope expects
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

echo "==> Installing Neovim (official release, apt's version is too old for LazyVim)"
if ! command -v nvim >/dev/null 2>&1 || [ "$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)" -lt 9 ]; then
  ARCH="$(uname -m)"
  if [ "$ARCH" = "aarch64" ]; then NVIM_ASSET="nvim-linux-arm64.tar.gz"; else NVIM_ASSET="nvim-linux-x86_64.tar.gz"; fi
  curl -fsSLo /tmp/nvim.tar.gz "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}"
  sudo rm -rf /opt/nvim
  sudo mkdir -p /opt/nvim
  sudo tar -xzf /tmp/nvim.tar.gz -C /opt/nvim --strip-components=1
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -f /tmp/nvim.tar.gz
fi

echo "==> Installing nvm + latest LTS Node (needed by Mason/LSP servers in LazyVim)"
if [ ! -d "$HOME/.nvm" ]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install --lts >/dev/null

echo "==> Installing starship prompt"
if ! command -v starship >/dev/null 2>&1; then
  mkdir -p "$HOME/.local/bin"
  curl -sS https://starship.rs/install.sh | sh -s -- -y --bin-dir "$HOME/.local/bin"
fi

echo "==> Cloning/updating nvim-config into ~/.config/nvim"
mkdir -p "$HOME/.config"
if [ -d "$HOME/.config/nvim/.git" ]; then
  git -C "$HOME/.config/nvim" pull --ff-only
else
  rm -rf "$HOME/.config/nvim"
  git clone "$NVIM_CONFIG_REPO" "$HOME/.config/nvim" || \
    git clone "https://github.com/Jpatching/nvim-config.git" "$HOME/.config/nvim"
fi

echo "==> Installing tmux plugin manager (TPM)"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

echo "==> Symlinking tmux/shell config"
ln -sf "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
ln -sf "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.config"
ln -sf "$DOTFILES_DIR/shell/starship.toml" "$HOME/.config/starship.toml"

echo "==> Installing TPM plugins non-interactively"
"$HOME/.tmux/plugins/tpm/bin/install_plugins" || true

echo "==> Setting zsh as default shell"
if [ "$SHELL" != "$(command -v zsh)" ]; then
  sudo chsh -s "$(command -v zsh)" "$USER" || chsh -s "$(command -v zsh)" || echo "  (chsh failed — run 'chsh -s \$(command -v zsh)' manually, may need password)"
fi

echo "==> Done. Log out/in (or 'exec zsh') to pick up the new shell."
echo "    Open nvim once to let Lazy sync plugins: nvim"
