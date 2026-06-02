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

# ---------- Colors (grayscale + navy/blue highlights) ----------
C0='%f%k'
FG_DIM='%F{240}'   # separators
FG_MUTE='%F{245}'  # host
FG_FG='%F{252}'    # cwd / text
FG_BLUE='%F{110}'  # accent: user + prompt symbol
FG_HI='%F{255}'    # bright
FG_BLK='%F{16}'    # black (text on light badge)

BG_NAVY='%K{17}'   # ok status badge (dark navy)
BG_LITE='%K{252}'  # err status badge (light gray, inverted)

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
  p+="${FG_BLUE}${u}${FG_DIM}@${FG_MUTE}${h}  "
  p+="${FG_DIM}@  "
  p+="${FG_FG}${cwd}${C0}"

  # Newline (REAL newline, not '\n')
  p+=$'\n'

  # Prompt line
  p+="${FG_BLUE}>>>${FG_HI} ${C0}"

  PROMPT="$p"

  # Right prompt (status + time)
  if [[ $__last_status -eq 0 ]]; then
    RPROMPT="${BG_NAVY}${FG_HI} ▲ %* ${C0}"
  else
    RPROMPT="${BG_LITE}${FG_BLK} ▼ %* ■ $__last_status ${C0}"
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
export EDITOR="${EDITOR:-issy}"
export PATH="/opt/homebrew/opt/ruby/bin:$HOME/.local/bin:$PATH"
# @@END_IF@@

# ---------- minimal fetch: hostname header, no logo, no user@host ----------
# ANSI slot 4 (blue) is light blue in our terminal palettes; 7 is light gray.
export PF_INFO="os kernel uptime pkgs memory shell"
export PF_COL1=4   # labels / accents
export PF_COL2=7   # values
# Interactive shells only, and not inside tmux (avoids per-pane spam).
if [[ -o interactive && -z "$TMUX" ]]; then
  command -v pfetch >/dev/null 2>&1 && { printf '\033[1;34m%s\033[0m\n' "$(hostname)"; pfetch; command -v sysinfo >/dev/null 2>&1 && sysinfo; }
fi
