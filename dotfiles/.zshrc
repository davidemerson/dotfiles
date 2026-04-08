########################################
#  David's zshrc
########################################

setopt prompt_subst
setopt no_beep
setopt interactive_comments
setopt hist_ignore_dups
setopt hist_reduce_blanks

HISTSIZE=20000
SAVEHIST=20000
HISTFILE=~/.zsh_history

autoload -Uz colors && colors
autoload -Uz add-zsh-hook

# ---------- Colors ----------
C0='%f%k'
FG_DIM='%F{240}'
FG_HI='%F{255}'

FG_CYAN='%F{81}'
FG_PURP='%F{141}'
FG_GREEN='%F{120}'
FG_PINK='%F{213}'

BG_ERR='%K{160}'
BG_OK='%K{235}'

# ---------- Exit status ----------
__last_status=0
precmd_status() { __last_status=$?; }
add-zsh-hook precmd precmd_status

# ---------- Prompt ----------
build_prompt() {
  local u="%n"
  local h="%m"
  local cwd="%~"

  local p=""

  # First line
  p+="${FG_CYAN}${u}${FG_DIM}@${FG_PURP}${h}  "
  p+="${FG_DIM}@  "
  p+="${FG_GREEN}${cwd}${C0}"

  # Newline (REAL newline, not '\n')
  p+=$'\n'

  # Prompt line
  p+="${FG_CYAN}>>>${FG_HI} ${C0}"

  PROMPT="$p"

  # Right prompt (status + time)
  if [[ $__last_status -eq 0 ]]; then
    RPROMPT="${BG_OK}${FG_DIM} ▲ %* ${C0}"
  else
    RPROMPT="${BG_ERR}${FG_HI} ▼ %* ■ $__last_status ${C0}"
  fi
}

add-zsh-hook precmd build_prompt

# ---------- Completion ----------
autoload -Uz compinit
compinit -d ~/.zcompdump

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# ---------- Keybindings ----------
bindkey -e
bindkey '^R' history-incremental-search-backward

# ---------- QoL ----------
setopt auto_cd
setopt correct
setopt extended_glob

# ---------- Aliases ----------
alias ls='lsd -laF'
alias ll='lsd -laF'
alias la='lsd -la'
alias top='btop'

# ---------- Env ----------
# @@IF_MACOS@@
export EDITOR="${EDITOR:-subl}"
export PATH="/opt/homebrew/opt/ruby/bin:$HOME/.local/bin:$PATH"
# @@END_IF@@
