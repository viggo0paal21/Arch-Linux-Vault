# ~/.zshrc

# --- History (wird zwischen allen Terminals geteilt) ---
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE

# --- Komfort ---
setopt AUTO_CD               # nur Ordnername tippen = hineinwechseln
setopt CORRECT               # "Meintest du ...?" bei Tippfehlern
setopt INTERACTIVE_COMMENTS

# --- Tab-Vervollständigung mit Menü, Groß/Klein egal ---
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

# --- Schutz vor rm-Unfällen ---
alias rm='rm --preserve-root=all'
alias sudo='sudo '

# --- Aus der .bashrc übernommen ---
alias ls='ls --color=auto'
alias grep='grep --color=auto'
export MOZ_ENABLE_WAYLAND=0
export MANGOHUD=1
export PATH="$PATH:/home/viggo/.local/bin"

# --- Starship-Prompt ---
eval "$(starship init zsh)"

# --- Plugins (Syntax-Highlighting muss ganz am Ende stehen) ---
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Unbekannte Befehle rot, aber nicht fett (gleiche Schrift wie der Rest)
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=9'


# --- Moderne Befehle ---
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --git --group-directories-first'
alias tree='eza --tree --icons'

# --- Nur gültige Befehle in die History ---
zshaddhistory() {
  local line=${1%%$'\n'}
  local cmd=${line%% *}
  [[ -z $cmd ]] && return 1                  # leere Zeilen nicht speichern
  whence "$cmd" > /dev/null 2>&1 || return 1 # unbekannter Befehl: nicht speichern
  return 0
}
