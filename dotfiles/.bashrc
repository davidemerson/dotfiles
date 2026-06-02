# @@IF_OPENBSD@@
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
if [ "$(tty)" = "/dev/ttyC0" ]; then
	startx
fi
# @@END_IF@@
# @@IF_LINUX@@
if [ "$(tty)" = "/dev/tty1" ]; then
	WLR_NO_HARDWARE_CURSORS=1 sway
fi
# @@END_IF@@

########################################
#  David's bash prompt (ported from zshrc)
########################################

# ---------- Colors (grayscale + navy/blue highlights) ----------
C0='\[\e[0m\]'
FG_DIM='\[\e[38;5;240m\]'   # separators
FG_MUTE='\[\e[38;5;245m\]'  # host
FG_FG='\[\e[38;5;252m\]'    # cwd / text
FG_BLUE='\[\e[38;5;110m\]'  # accent: user + prompt symbol
FG_HI='\[\e[38;5;255m\]'    # bright
FG_BLK='\[\e[38;5;16m\]'    # black (text on light badge)

BG_NAVY='\[\e[48;5;17m\]'   # ok status badge (dark navy)
BG_LITE='\[\e[48;5;252m\]'  # err status badge (light gray, inverted)

# ---------- Prompt ----------
__build_prompt() {
  local exit_code=$?
  local time_now
  time_now=$(date +%T)

  # Status badge (right-aligned on first line via cursor positioning)
  local status_text status_styled status_len
  if [[ $exit_code -eq 0 ]]; then
    status_text=" ▲ ${time_now} "
    status_styled="${BG_NAVY}${FG_HI}${status_text}${C0}"
  else
    status_text=" ▼ ${time_now} ■ ${exit_code} "
    status_styled="${BG_LITE}${FG_BLK}${status_text}${C0}"
  fi
  status_len=${#status_text}

  # Move cursor to (cols - status_len + 1) to right-align
  local col=$(( $(tput cols) - status_len + 1 ))
  local move_right="\[\e[${col}G\]"

  local line1="${FG_BLUE}\u${FG_DIM}@${FG_MUTE}\h  ${FG_DIM}@  ${FG_FG}\w${C0}"

  PS1="${line1}${move_right}${status_styled}\n${FG_BLUE}>>>${FG_HI} ${C0}"
}

PROMPT_COMMAND=__build_prompt

# ---------- History ----------
HISTSIZE=20000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# ---------- QoL ----------
shopt -s autocd 2>/dev/null
shopt -s cdspell
shopt -s globstar 2>/dev/null

# ---------- Aliases ----------
alias ls='lsd -laF'
alias ll='lsd -laF'
alias la='lsd -la'
alias top='btop'

# ---------- Env ----------
export EDITOR="${EDITOR:-issy}"
export PATH="$HOME/bin:/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# ---------- pfetch (minimal system fetch) ----------
# ANSI slot 4 (blue) is light blue in our terminal palettes; 7 is light gray.
export PF_INFO="ascii title os host kernel uptime pkgs memory shell"
export PF_COL1=4   # labels / accents
export PF_COL2=7   # values
export PF_COL3=4   # user@host
# Run only in interactive shells, and not inside tmux (avoids per-pane spam).
case $- in
  *i*) [ -z "$TMUX" ] && command -v pfetch >/dev/null 2>&1 && pfetch ;;
esac
