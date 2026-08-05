export EDITOR=nvim
export VISUAL=nvim
export PATH="$HOME/.local/bin:$PATH"

# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

# Sane defaults
setopt AUTO_CD
setopt CORRECT
bindkey -e

# Completion
autoload -Uz compinit && compinit

# Aliases
alias ls='eza --icons 2>/dev/null || ls --color=auto'
alias ll='eza -la --icons 2>/dev/null || ls -la --color=auto'
alias cat='bat --paging=never 2>/dev/null || cat'
alias vim='nvim'
alias vi='nvim'
alias tm='tmux new -As main'
alias gs='git status'
alias gd='git diff'
alias gc='git commit'
alias gp='git push'

# nvm (installed by bootstrap.sh)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Starship prompt (installed by bootstrap.sh)
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

# Auto-attach tmux on interactive SSH login (skip if already inside tmux)
if [ -z "$TMUX" ] && [ -n "$SSH_CONNECTION" ] && [ -t 1 ]; then
  tmux new -As main
fi
