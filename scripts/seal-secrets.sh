#!/bin/sh
# Seal the private assets listed in scripts/secrets.manifest into an encrypted
# bundle for provision.sh to fetch.
#
# WHY THIS EXISTS: some things a machine needs at provision time cannot live in
# this repository, because the repository is public -- a commercial font whose
# binary is watermarked with the licensee's ID, and in future whatever else
# gets added to the manifest. They go in one symmetrically-encrypted bundle
# instead, published at a fixed URL. The ciphertext being fetchable by anyone
# is fine and is the point: a fresh machine has no credential, so the ONE thing
# a human supplies is the passphrase, and everything else follows from it.
#
# WHY gpg AND NOT age: age deliberately refuses to read a passphrase from
# anything but /dev/tty, so it cannot decrypt during an unattended provision --
# tested, it fails with "standard input is not a terminal". gpg --batch
# --passphrase-fd 0 does the job, is already installed on every platform this
# repo targets, and still prompts naturally when a human is present.
#
# Run this from a machine that already has every file the manifest lists, in
# the place the manifest says it belongs. Then publish the bundle:
#
#   sh scripts/seal-secrets.sh
#   aws --profile <p> s3 cp nnix-secrets.tar.gpg \
#       s3://nnix.com/provisioning/nnix-secrets.tar.gpg \
#       --content-type application/octet-stream \
#       --cache-control "max-age=300, must-revalidate"
#
# Requires: gpg tar

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TREE="$(cd "$SCRIPT_DIR/.." && pwd)"
MANIFEST="$SCRIPT_DIR/secrets.manifest"
OUT="${1:-$TREE/nnix-secrets.tar.gpg}"

[ -f "$MANIFEST" ] || { echo "no manifest at $MANIFEST" >&2; exit 1; }
command -v gpg >/dev/null 2>&1 || { echo "gpg is required" >&2; exit 1; }

# Stage in memory where we can: the whole point is to avoid leaving plaintext
# copies of these files lying around on disk.
for d in /dev/shm /run/user/"$(id -u)" /tmp; do
    [ -d "$d" ] && [ -w "$d" ] && { STAGE_PARENT="$d"; break; }
done
STAGE="$(mktemp -d "${STAGE_PARENT:-/tmp}/nnix-seal.XXXXXX")"
trap 'find "$STAGE" -type f -exec shred -u {} + 2>/dev/null || true; rm -rf "$STAGE"' EXIT INT TERM
mkdir -p "$STAGE/payload"
cp "$MANIFEST" "$STAGE/manifest"

missing=0
count=0
# `owner` is read only to consume that manifest column -- it is provision.sh,
# not this script, that acts on it.
# shellcheck disable=SC2034
while read -r name dest mode owner rest; do
    case "${name:-}" in ''|\#*) continue ;; esac
    [ -n "${dest:-}" ] && [ -n "${mode:-}" ] || { echo "malformed manifest line: $name" >&2; exit 1; }
    # On the sealing host, each file already sits at its own destination.
    src="$(printf '%s' "$dest" | sed -e "s|@@TREE@@|$TREE|g" -e "s|@@HOME@@|$HOME|g")"
    if [ ! -f "$src" ]; then
        echo "  MISSING  $name  (expected at $src)" >&2
        missing=$((missing + 1))
        continue
    fi
    cp "$src" "$STAGE/payload/$name"
    printf '  sealed   %-28s %s\n' "$name" "$(sha256sum "$src" | cut -c1-16)…"
    count=$((count + 1))
done < "$MANIFEST"

[ "$missing" -eq 0 ] || { echo "$missing file(s) missing; refusing to seal a partial bundle" >&2; exit 1; }
[ "$count" -gt 0 ]   || { echo "manifest listed nothing" >&2; exit 1; }

tar -C "$STAGE" -cf "$STAGE/bundle.tar" manifest payload

# Max-strength S2K. This ciphertext is published, so the KDF cost is the only
# thing standing between a copy of the file and an offline guessing attack --
# use a passphrase with real entropy behind it.
if [ -n "${NNIX_SECRETS_PASSPHRASE:-}" ]; then
    printf '%s' "$NNIX_SECRETS_PASSPHRASE" | gpg --batch --yes --quiet --passphrase-fd 0 \
        --symmetric --cipher-algo AES256 --s2k-mode 3 --s2k-digest-algo SHA512 \
        --s2k-count 65011712 -o "$OUT" "$STAGE/bundle.tar"
else
    gpg --yes --quiet \
        --symmetric --cipher-algo AES256 --s2k-mode 3 --s2k-digest-algo SHA512 \
        --s2k-count 65011712 -o "$OUT" "$STAGE/bundle.tar"
fi

chmod 0644 "$OUT"
echo
echo "Sealed $count file(s) -> $OUT"
echo "  sha256 $(sha256sum "$OUT" | cut -d' ' -f1)"
echo "  size   $(stat -c%s "$OUT") bytes"
