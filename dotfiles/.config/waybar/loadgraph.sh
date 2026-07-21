#!/bin/sh
# waybar custom module: a rolling sparkline of the 1-minute load average over
# roughly the last minute (interval 3s x 20 samples). On-brand gray->blue
# gradient — taller and bluer means heavier load — colored via pango markup.
# The graph is always drawn at full width (N bars): while the history is still
# filling, the oldest sample is repeated to pad the window, so it starts full
# instead of visibly growing in over the first minute. State is a small rolling
# buffer in the user's runtime dir. POSIX + mawk-safe (awk only ever touches
# numbers; the multibyte block glyphs live in the shell, since Debian's default
# mawk is not UTF-8 aware).

hist="${XDG_RUNTIME_DIR:-/tmp}/waybar-loadgraph.$(id -u)"
N=20

load=$(awk '{print $1}' /proc/loadavg 2>/dev/null)
[ -n "$load" ] || exit 0
ncpu=$(nproc 2>/dev/null || echo 1)

# append the current sample, keep only the last N
printf '%s\n' "$load" >> "$hist"
tail -n "$N" "$hist" > "$hist.tmp" 2>/dev/null && mv "$hist.tmp" "$hist"

# map each sample to a level 1..8, normalized by core count (numbers only)
levels=$(awk -v ncpu="$ncpu" '
  { f = $1 / ncpu; if (f > 1) f = 1
    l = int(f * 7 + 0.5) + 1; if (l < 1) l = 1; if (l > 8) l = 8
    print l }' "$hist")

# pad to a full N-wide window by repeating the oldest level, so the bar is
# always full width rather than growing in as history accumulates
set -- $levels
while [ "$#" -lt "$N" ] && [ -n "$1" ]; do
  set -- "$1" "$@"
done

out=""
for lvl in "$@"; do
  case $lvl in
    1) g="▁"; c="#666666" ;;
    2) g="▂"; c="#808080" ;;
    3) g="▃"; c="#999999" ;;
    4) g="▄"; c="#6a86b0" ;;
    5) g="▅"; c="#8fb6e0" ;;
    6) g="▆"; c="#a6c6e8" ;;
    7) g="▇"; c="#bcd6f2" ;;
    8) g="█"; c="#d6e6fa" ;;
  esac
  out="$out<span color=\"$c\">$g</span>"
done

# sparkline followed by the current 1-min load value (muted)
printf '%s <span color="#999999">%s</span>\n' "$out" "$load"
