# @@IF_OPENBSD@@
if [ -z "$XDG_RUNTIME_DIR" ]; then
	export XDG_RUNTIME_DIR="/tmp/run-$(id -u)"
	mkdir -p "$XDG_RUNTIME_DIR"
	chmod 700 "$XDG_RUNTIME_DIR"
fi
if [ "$(tty)" = "/dev/ttyC0" ]; then
	WLR_NO_HARDWARE_CURSORS=1 WLR_RENDERER=pixman sway
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

# ---------- Colors ----------
C0='\[\e[0m\]'
FG_DIM='\[\e[38;5;240m\]'
FG_HI='\[\e[38;5;255m\]'

FG_CYAN='\[\e[38;5;81m\]'
FG_PURP='\[\e[38;5;141m\]'
FG_GREEN='\[\e[38;5;120m\]'

BG_ERR='\[\e[48;5;160m\]'
BG_OK='\[\e[48;5;235m\]'

# ---------- Prompt ----------
__build_prompt() {
  local exit_code=$?
  local time_now
  time_now=$(date +%T)

  # Status badge (right-aligned on first line via cursor positioning)
  local status_text status_styled status_len
  if [[ $exit_code -eq 0 ]]; then
    status_text=" ▲ ${time_now} "
    status_styled="${BG_OK}${FG_DIM}${status_text}${C0}"
  else
    status_text=" ▼ ${time_now} ■ ${exit_code} "
    status_styled="${BG_ERR}${FG_HI}${status_text}${C0}"
  fi
  status_len=${#status_text}

  # Move cursor to (cols - status_len + 1) to right-align
  local col=$(( $(tput cols) - status_len + 1 ))
  local move_right="\[\e[${col}G\]"

  local line1="${FG_CYAN}\u${FG_DIM}@${FG_PURP}\h  ${FG_DIM}@  ${FG_GREEN}\w${C0}"

  PS1="${line1}${move_right}${status_styled}\n${FG_CYAN}>>>${FG_HI} ${C0}"
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

# ---------- Env ----------
# @@IF_OPENBSD@@
export EDITOR="${EDITOR:-nano}"
# @@END_IF@@
# @@IF_LINUX@@
export EDITOR="${EDITOR:-subl}"
# @@END_IF@@
# @@IF_MACOS@@
export EDITOR="${EDITOR:-nano}"
# @@END_IF@@
export PATH="$HOME/bin:/usr/local/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
