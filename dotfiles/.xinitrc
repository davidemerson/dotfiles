#!/bin/sh
# Remove duplicate Super_L mapping that causes i3 bindings to fire twice
xmodmap -e 'remove mod4 = Super_L' -e 'add mod4 = Super_L' 2>/dev/null
exec i3
