# ~/.zshrc

# --- History (shared between all terminals) ---
HISTFILE=~/.local/state/zsh/history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE

# --- Komfort ---
setopt AUTO_CD               # type just a folder name = cd into it
setopt CORRECT               # "Did you mean ...?" on typos
setopt INTERACTIVE_COMMENTS

# --- Tab completion with menu, case-insensitive ---
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

# --- Tasten: Pos1, Ende, Entf, Strg+Pfeile ---
bindkey -e
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# --- Protection against rm accidents ---
alias rm='rm --preserve-root=all'
alias sudo='sudo '

# --- Taken over from .bashrc ---
alias ls='ls --color=auto'
alias grep='grep --color=auto'
export MOZ_ENABLE_WAYLAND=0
export MANGOHUD=1
# ~/.local/bin first, so the qs/quickshell wrappers win over /usr/bin
export PATH="$HOME/.local/bin:$PATH"

# --- Starship-Prompt ---
eval "$(starship init zsh)"

# --- Plugins (syntax highlighting has to be at the very end) ---
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Unknown commands red, but not bold (same font as the rest)
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=9'


# --- Moderne Befehle ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --git --group-directories-first'
alias tree='eza --tree --icons'

# --- Only valid commands go into the history ---
zshaddhistory() {
  local line=${1%%$'\n'}
  local cmd=${line%% *}
  [[ -z $cmd ]] && return 1                  # don't save empty lines
  whence "$cmd" > /dev/null 2>&1 || return 1 # unknown command: don't save
  return 0
}
