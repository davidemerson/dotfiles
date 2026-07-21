#!/bin/sh
# Rename the tuigreet prompt-box title from "Authenticate into <hostname>" to
# "Login".
#
# tuigreet 0.9.1 hardcodes the title as the fluent message
# `title_authenticate = Authenticate into {$hostname}`, embedded in the binary
# via rust-embed with no CLI flag or config override. The hostname already
# shows in the --greeting line inside the same box, so that title just repeats
# it. We patch the embedded en-US locale in place.
#
# The patch is length-preserving: rust-embed records each asset's byte length,
# so we replace the message with "Login" padded by trailing spaces (Fluent
# trims trailing whitespace from a value) to keep the .ftl blob the same size.
#
# This is a binary patch and is reverted whenever the tuigreet package is
# upgraded or reinstalled. provision.sh re-applies it on every run; run this by
# hand (with sudo) after a tuigreet upgrade. Idempotent — safe to re-run.
#
# Requires: python3   (root, to write /usr/bin/tuigreet)

set -eu

TG="$(command -v tuigreet 2>/dev/null || echo /usr/bin/tuigreet)"
[ -f "$TG" ] || { echo "tuigreet not found; skipping title patch" >&2; exit 0; }

python3 - "$TG" <<'PY'
import sys

path = sys.argv[1]
data = bytearray(open(path, "rb").read())

old = b"title_authenticate = Authenticate into {$hostname}"
new = b"title_authenticate = Login"
# Fluent trims trailing whitespace, so padding spaces keep the byte length
# without changing the rendered value.
replacement = new + b" " * (len(old) - len(new))
assert len(replacement) == len(old)

if data.find(replacement) != -1:
    print("tuigreet title already patched -> Login")
    sys.exit(0)

first = data.find(old)
if first == -1:
    print("tuigreet title string not found (version changed?); "
          "leaving binary untouched", file=sys.stderr)
    sys.exit(0)
if data.find(old, first + 1) != -1:
    print("tuigreet title string found more than once; refusing to patch",
          file=sys.stderr)
    sys.exit(1)

data[first:first + len(old)] = replacement
open(path, "wb").write(data)
print("patched tuigreet title -> Login")
PY
