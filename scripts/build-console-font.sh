#!/bin/sh
# Regenerate the Berkeley Mono console font (scripts/BerkeleyMonoNNIX.psf.gz).
#
# The Linux VT console (tty1-6 and the tuigreet greeter on vt7) can only render
# fixed-cell PSF bitmap fonts, not the bmv.otf vector font used by st/dmenu/
# waybar. This rasterizes bmv.otf into a ~16x32 PSF so the console matches.
#
# Run this by hand whenever dotfiles/.fonts/bmv.otf changes, then commit the
# regenerated .psf.gz. provision.sh ships the prebuilt artifact — it does NOT
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

# -p 24 @ 75dpi yields a 15x31 bounding box — the largest that fits the
# console's 32px height ceiling with a byte-aligned width.
otf2bdf -p 24 -r 75 "$OTF" -o "$TMP/bmv.bdf"

# otf2bdf mislabels this monospace face as proportional (SPACING "P"), which
# bdf2psf rejects ("width is not integer number"). DWIDTH is a uniform 15 0,
# so rewrite the XLFD/SPACING metadata to character-cell.
sed -i \
    -e 's/-P-108-ISO10646-1/-C-150-ISO10646-1/' \
    -e 's/^SPACING "P"/SPACING "C"/' \
    -e 's/^AVERAGE_WIDTH .*/AVERAGE_WIDTH 150/' \
    "$TMP/bmv.bdf"

# Pack into a 512-glyph PSF2 with ASCII + useful symbols + Linux box-drawing
# (tuigreet frames its UI with box-drawing glyphs).
bdf2psf --fb "$TMP/bmv.bdf" \
    "$D/standard.equivalents" \
    "$D/ascii.set+$D/useful.set+$D/linux.set" \
    512 "$TMP/BerkeleyMonoNNIX.psf"

gzip -9 -c "$TMP/BerkeleyMonoNNIX.psf" > "$OUT"
echo "Wrote $OUT ($(zcat "$OUT" | file - | sed 's|/dev/stdin: ||'))"
