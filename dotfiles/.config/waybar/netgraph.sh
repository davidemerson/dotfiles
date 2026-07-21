#!/bin/sh
# waybar custom module: two rolling sparklines of network throughput summed over
# all real interfaces (loopback and virtual ifaces excluded to avoid double
# counting) across ~the last half-minute (interval 3s x 10 samples). One line
# for inbound (RX, down arrow), one for outbound (TX, up arrow) — each half the
# width of the load histogram so the pair isn't absurdly long. On-brand
# gray->blue gradient on a log2 scale (taller/bluer means faster) via pango
# markup, with the current rate in human units after each bar. State (previous
# byte counters + rolling rate buffers) lives in the user's runtime dir. POSIX +
# mawk-safe: awk only ever touches numbers; the block glyphs live in the shell,
# since Debian's default mawk is not UTF-8 aware.

state="${XDG_RUNTIME_DIR:-/tmp}/waybar-netgraph.$(id -u)"
rxh="$state.rx"   # rolling inbound  rate history (bytes/sec, one per line)
txh="$state.tx"   # rolling outbound rate history
prev="$state.prev"
N=10

# Sum cumulative RX/TX bytes across physical interfaces. /proc/net/dev columns
# after the "iface:" are rxbytes(1) ... txbytes(9). lo and virtual ifaces
# (docker/veth/bridge/vpn/etc.) are skipped so tunnelled traffic isn't tallied
# twice against its physical carrier.
totals=$(awk '
  /:/ {
    split($0, a, ":"); name = a[1]; gsub(/[ \t]/, "", name)
    if (name ~ /^(lo|veth|docker|br-|virbr|vnet|vmnet|zt|tun|tap|wg|ppp)/) next
    n = split(a[2], f)
    rx += f[1]; tx += f[9]
  }
  END { print rx+0, tx+0 }' /proc/net/dev)
rx=${totals% *}
tx=${totals#* }

now=$(date +%s.%N)
prx=""; ptx=""; pt=""
[ -f "$prev" ] && read -r prx ptx pt < "$prev"
printf '%s %s %s\n' "$rx" "$tx" "$now" > "$prev"

# Per-second rates from the delta since the last sample; guard first run and
# counter resets (negative deltas) to 0.
rates=$(awk -v rx="$rx" -v tx="$tx" -v prx="$prx" -v ptx="$ptx" -v now="$now" -v pt="$pt" 'BEGIN{
  dt = now - pt; if (dt <= 0) dt = 1
  rr = (prx == "") ? 0 : (rx - prx) / dt; if (rr < 0) rr = 0
  tr = (ptx == "") ? 0 : (tx - ptx) / dt; if (tr < 0) tr = 0
  print rr, tr }')
inrate=${rates% *}
outrate=${rates#* }

# append current rates, keep only the last N
printf '%s\n' "$inrate"  >> "$rxh"; tail -n "$N" "$rxh" > "$rxh.tmp" 2>/dev/null && mv "$rxh.tmp" "$rxh"
printf '%s\n' "$outrate" >> "$txh"; tail -n "$N" "$txh" > "$txh.tmp" 2>/dev/null && mv "$txh.tmp" "$txh"

# render one sparkline (pango markup) from a rate-history file
render() {
  # map each rate to a level 1..8 on a log2 scale: <=1KiB/s -> 1, ~1GiB/s -> 8
  levels=$(awk '{
    r = $1; if (r < 1024) { print 1; next }
    l = int((log(r)/log(2) - 10) / 2.5) + 1
    if (l < 1) l = 1; if (l > 8) l = 8
    print l }' "$1")
  # pad to a full N-wide window by repeating the oldest level
  set -- $levels
  while [ "$#" -lt "$N" ] && [ -n "$1" ]; do set -- "$1" "$@"; done
  [ -n "$1" ] || set -- 1 1 1 1 1 1 1 1 1 1
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
  printf '%s' "$out"
}

# human-readable rate, kept short (e.g. 0B, 830K, 1.2M)
fmt() {
  awk -v r="$1" 'BEGIN{
    u="B"
    if (r >= 1024) { r/=1024; u="K" }
    if (r >= 1024) { r/=1024; u="M" }
    if (r >= 1024) { r/=1024; u="G" }
    if (u == "B" || r >= 100) printf "%d%s", r, u; else printf "%.1f%s", r, u }'
}

inbar=$(render "$rxh")
outbar=$(render "$txh")

# down arrow = inbound, up arrow = outbound; rates muted after each bar
printf '<span color="#999999">↓</span>%s <span color="#999999">%s</span>  <span color="#999999">↑</span>%s <span color="#999999">%s</span>\n' \
  "$inbar" "$(fmt "$inrate")" "$outbar" "$(fmt "$outrate")"
