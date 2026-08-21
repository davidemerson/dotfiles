#!/bin/sh
# Regenerate the Berkeley Mono console font (scripts/BerkeleyMonoNNIX.psf.gz).
#
# The Linux VT console (tty1-6 and the tuigreet greeter on vt7) can only render
# fixed-cell PSF bitmap fonts, not the bmv.otf vector font used by st/dmenu/
# waybar. This rasterizes bmv.otf into an 8x16 PSF so the console matches.
#
# On cell size: this used to rasterize the largest cell the console can take
# (15x29, from -p 24). That is far too big on a 4K panel -- a full-screen
# console is only 256x74 characters and boot messages are legible from across
# the room. 8x16 is the classic Linux console cell instead: it is what the
# kernel's own built-in font uses, it is byte-aligned (8 pixels is exactly one
# byte per row, which is also why bdf2psf emits PSF1 rather than PSF2 at this
# width), and it is a size every display from 1080p up renders sensibly.
#
# Run this by hand whenever dotfiles/.fonts/bmv.otf changes, then commit the
# regenerated .psf.gz. provision.sh ships the prebuilt artifact -- it does NOT
# build at provision time (otf2bdf/bdf2psf are not runtime dependencies).
#
# Requires: otf2bdf bdf2psf gzip   (apt install otf2bdf bdf2psf)

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OTF="$SCRIPT_DIR/../dotfiles/.fonts/bmv.otf"
OUT="$SCRIPT_DIR/BerkeleyMonoNNIX.psf.gz"
D=/usr/share/bdf2psf
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# -p 13 @ 75dpi yields an 8x16 cell. Change this one number to resize the
# console font; everything downstream derives from the resulting metrics.
POINT_SIZE=13

# otf2bdf exits non-zero (8) merely because bmv.otf has no glyph for a couple
# of codepoints in bdf2psf's "useful" set, while still writing a perfectly good
# BDF. Under `set -e` that aborted the build, so judge it by its output rather
# than its status.
otf2bdf -p "$POINT_SIZE" -r 75 "$OTF" -o "$TMP/bmv.bdf" || true
[ -s "$TMP/bmv.bdf" ] || { echo "otf2bdf produced no output" >&2; exit 1; }

# otf2bdf mislabels this monospace face as proportional (SPACING "P"), which
# bdf2psf rejects ("width is not integer number"). DWIDTH is uniform, so
# rewrite the XLFD/SPACING metadata to character-cell. Derive the width from
# the font rather than hardcoding it -- the XLFD carries average width in
# tenths of a pixel, so those numbers change with POINT_SIZE.
dwidth=$(awk '/^DWIDTH/ { print $2; exit }' "$TMP/bmv.bdf")
avg_width=$((dwidth * 10))

sed -i \
    -e "s/-P-[0-9]*-ISO10646-1/-C-$avg_width-ISO10646-1/" \
    -e 's/^SPACING "P"/SPACING "C"/' \
    -e "s/^AVERAGE_WIDTH .*/AVERAGE_WIDTH $avg_width/" \
    "$TMP/bmv.bdf"

# Pack into a 512-glyph PSF with ASCII + useful symbols + Linux box-drawing
# (tuigreet frames its UI with box-drawing glyphs).
bdf2psf --fb "$TMP/bmv.bdf" \
    "$D/standard.equivalents" \
    "$D/ascii.set+$D/useful.set+$D/linux.set" \
    512 "$TMP/BerkeleyMonoNNIX.psf"

gzip -9 -c "$TMP/BerkeleyMonoNNIX.psf" > "$OUT"
echo "Wrote $OUT ($(zcat "$OUT" | file - | sed 's|/dev/stdin: ||'))"
