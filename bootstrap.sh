#!/usr/bin/env bash
# Idempotent dev environment bootstrap for Ubuntu / WSL2.
# Run from inside a cloned copy of this repo: ~/dotfiles/bootstrap.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NVIM_CONFIG_REPO="git@github.com:Jpatching/nvim-config.git"
ARCH="$(uname -m)"

echo "==> Updating apt and installing base packages"
sudo apt-get update -y
sudo apt-get install -y \
  git curl unzip build-essential \
  zsh tmux ripgrep fd-find xclip \
  fzf bat zoxide direnv eza \
  ca-certificates gnupg

# fd/bat are packaged under different names on Ubuntu; symlink to the names tools expect
mkdir -p "$HOME/.local/bin"
if ! command -v fd >/dev/null 2>&1 && command -v fdfind >/dev/null 2>&1; then
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi
if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
  ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
fi

echo "==> Installing Neovim (official release, apt's version is too old for LazyVim)"
if ! command -v nvim >/dev/null 2>&1 || [ "$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1 | cut -d. -f2)" -lt 9 ]; then
  if [ "$ARCH" = "aarch64" ]; then NVIM_ASSET="nvim-linux-arm64.tar.gz"; else NVIM_ASSET="nvim-linux-x86_64.tar.gz"; fi
  curl -fsSLo /tmp/nvim.tar.gz "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}"
  sudo rm -rf /opt/nvim
  sudo mkdir -p /opt/nvim
  sudo tar -xzf /tmp/nvim.tar.gz -C /opt/nvim --strip-components=1
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm -f /tmp/nvim.tar.gz
fi

echo "==> Installing nvm + latest LTS Node (needed by Mason/LSP servers in LazyVim)"
if [ ! -s "$HOME/.nvm/nvm.sh" ]; then
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

echo "==> Installing lazygit"
if ! command -v lazygit >/dev/null 2>&1; then
  LG_VER="$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')"
  if [ "$ARCH" = "aarch64" ]; then LG_ASSET="lazygit_${LG_VER}_linux_arm64.tar.gz"; else LG_ASSET="lazygit_${LG_VER}_linux_x86_64.tar.gz"; fi
  curl -fsSLo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LG_VER}/${LG_ASSET}"
  mkdir -p /tmp/lazygit-extract && tar -xzf /tmp/lazygit.tar.gz -C /tmp/lazygit-extract lazygit
  sudo install -m 755 /tmp/lazygit-extract/lazygit /usr/local/bin/lazygit
  rm -rf /tmp/lazygit.tar.gz /tmp/lazygit-extract
fi

echo "==> Installing delta (git diff pager)"
if ! command -v delta >/dev/null 2>&1; then
  DL_VER="$(curl -fsSL https://api.github.com/repos/dandavison/delta/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)"
  if [ "$ARCH" = "aarch64" ]; then DL_ASSET="delta-${DL_VER#v}-aarch64-unknown-linux-gnu.tar.gz"; else DL_ASSET="delta-${DL_VER#v}-x86_64-unknown-linux-gnu.tar.gz"; fi
  curl -fsSLo /tmp/delta.tar.gz "https://github.com/dandavison/delta/releases/download/${DL_VER}/${DL_ASSET}"
  mkdir -p /tmp/delta-extract && tar -xzf /tmp/delta.tar.gz -C /tmp/delta-extract
  sudo install -m 755 "$(find /tmp/delta-extract -maxdepth 2 -type f -name delta)" /usr/local/bin/delta
  rm -rf /tmp/delta.tar.gz /tmp/delta-extract
fi
git config --global core.pager delta
git config --global interactive.diffFilter "delta --color-only"
git config --global delta.navigate true
git config --global merge.conflictStyle diff3

echo "==> Installing atuin (shell history sync)"
if ! command -v atuin >/dev/null 2>&1; then
  AT_VER="$(curl -fsSL https://api.github.com/repos/atuinsh/atuin/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)"
  if [ "$ARCH" = "aarch64" ]; then AT_ASSET="atuin-aarch64-unknown-linux-musl.tar.gz"; else AT_ASSET="atuin-x86_64-unknown-linux-musl.tar.gz"; fi
  curl -fsSLo /tmp/atuin.tar.gz "https://github.com/atuinsh/atuin/releases/download/${AT_VER}/${AT_ASSET}"
  mkdir -p /tmp/atuin-extract && tar -xzf /tmp/atuin.tar.gz -C /tmp/atuin-extract
  sudo install -m 755 "$(find /tmp/atuin-extract -maxdepth 2 -type f -name atuin)" /usr/local/bin/atuin
  rm -rf /tmp/atuin.tar.gz /tmp/atuin-extract
fi
# atuin register/login is interactive (needs a real terminal) — not scripted here, see README note.

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
echo "    Run 'atuin register' (or 'atuin login') once, interactively, to enable synced shell history."
