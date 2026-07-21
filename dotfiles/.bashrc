# Guard against being sourced twice in one shell: .bash_profile sources both
# the stock ~/.profile (which re-sources .bashrc) and .bashrc directly, which
# would otherwise double the PATH and print the login banner twice.
[ -n "${__NNIX_BASHRC:-}" ] && return
__NNIX_BASHRC=1

# ---------- ssh-agent: one shared agent per user ----------
# macOS runs an agent via launchd; the bash platforms (Linux/OpenBSD) do
# not, so start one bound to a fixed socket and reuse it across every shell
# and the WM session launched below. Without this, `workstation` and SSH
# commit signing have no agent to load the key into. Runs before the WM
# launch so sway/i3 (and their terminals) inherit SSH_AUTH_SOCK.
# ssh-add -l exit codes: 0 = has keys, 1 = agent up/no keys, 2 = no agent.
#
# Then load the git identity / signing key once per session (prompts for the
# passphrase a single time; later shells find it already loaded and skip).
# The agent matches keys by their blob, not filename, so the id_d_nnix.pem /
# id_d_nnix.pub naming that otherwise breaks `ssh-keygen -Y sign` is fine once
# the key is in the agent. This is what makes SSH commit signing and git push
# over ssh "just work" on this machine. Ctrl+C at the prompt to skip.
# Point at our fixed shared-agent socket, but don't clobber a working agent
# already in the environment (e.g. a forwarded `ssh -A` socket) — only default
# to the fixed path when nothing usable was inherited.
if [ -z "${SSH_AUTH_SOCK:-}" ] || [ ! -S "${SSH_AUTH_SOCK:-}" ]; then
  export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/tmp}/ssh-agent-$(id -u).sock"
fi
case $- in
  *i*)
    ssh-add -l >/dev/null 2>&1
    if [ $? -ge 2 ]; then
      rm -f "$SSH_AUTH_SOCK"
      ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null 2>&1
    fi
    if [ -r "$HOME/.ssh/id_d_nnix.pem" ] && [ -r "$HOME/.ssh/id_d_nnix.pub" ]; then
      __sk_fp=$(ssh-keygen -lf "$HOME/.ssh/id_d_nnix.pub" 2>/dev/null | awk '{print $2}')
      if [ -n "$__sk_fp" ] && ! ssh-add -l 2>/dev/null | grep -qF "$__sk_fp"; then
        ssh-add "$HOME/.ssh/id_d_nnix.pem" 2>/dev/null || true
      fi
      unset __sk_fp
    fi
    ;;
esac

# @@IF_OPENBSD@@
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8
if [ "$(tty)" = "/dev/ttyC0" ]; then
	startx
fi
# @@END_IF@@
# @@IF_LINUX@@
export XCURSOR_THEME=plan9
export XCURSOR_SIZE=16
# Qt apps (VLC, etc.) follow the dark theme via adwaita-qt6.
export QT_STYLE_OVERRIDE=Adwaita-Dark
export WLR_NO_HARDWARE_CURSORS=1
# Normally greetd (the login manager) starts sway on vt7 via sway-session.
# This is only a fallback: from a tty1 console login, launch sway when greetd
# is not running, so a broken/absent greeter never locks you out of the desktop.
if [ "$(tty)" = "/dev/tty1" ] && ! systemctl is-active --quiet greetd 2>/dev/null; then
	exec sway
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
# Prepend without creating duplicates when a nested shell re-sources this.
__path_prepend() { case ":$PATH:" in *":$1:"*) : ;; *) PATH="$1:$PATH" ;; esac; }
__path_prepend /usr/local/bin
__path_prepend "$HOME/bin"
__path_prepend "$HOME/.local/bin"
unset -f __path_prepend
export PATH

# ---------- fzf (Ctrl-R history, Ctrl-T files) + fd ----------
command -v fzf >/dev/null 2>&1 && eval "$(fzf --bash 2>/dev/null)"
# Debian ships fd as 'fdfind'; give it its usual name (and let fzf use it)
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  alias fd=fdfind
  export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --exclude .git'
elif command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
fi

# ---------- colored man/less (palette: light blue / navy / white) ----------
export LESS=-R
export LESS_TERMCAP_md=$'\e[1;38;5;110m'        # bold      -> light blue (headings)
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;38;5;152m'        # underline -> pale blue (options)
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_so=$'\e[48;5;17;38;5;255m'  # standout  -> navy bg / white (search, prompt)
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_mb=$'\e[1;38;5;110m'        # blink     -> light blue

# ---------- minimal fetch: hostname header, no logo, no user@host ----------
# ANSI slot 4 (blue) is light blue in our terminal palettes; 7 is light gray.
export PF_INFO="os shell uptime memory"   # cpu/disk/epoch added by sysinfo
export PF_COL1=4   # labels / accents
export PF_COL2=7   # values
# Interactive shells only, and not inside tmux (avoids per-pane spam).
# sed strips pfetch's trailing blank line so sysinfo's lines abut it.
case $- in
  *i*) if [ -z "$TMUX" ] && command -v pfetch >/dev/null 2>&1; then
         printf '\033[1;34m%s\033[0m\n' "$(hostname)"
         pfetch | sed '/^[[:space:]]*$/d'
         command -v sysinfo >/dev/null 2>&1 && sysinfo
       fi ;;
esac
