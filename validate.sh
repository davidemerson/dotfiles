#!/bin/sh

# Dotfiles configuration validator

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
pass=0
fail=0

check() {
    if [ -f "$SCRIPT_DIR/$1" ]; then
        printf "${GREEN}✓${NC} %s\n" "$1"
        pass=$((pass + 1))
    else
        printf "${RED}✗${NC} %s\n" "$1"
        fail=$((fail + 1))
    fi
}

printf "Validating dotfiles...\n\n"

printf "Core files:\n"
check "provision.sh"

printf "\nDotfiles:\n"
check "dotfiles/.bashrc"
check "dotfiles/.gitconfig"
check "dotfiles/.config/sway/config"
check "dotfiles/.config/foot/foot.ini"
check "dotfiles/.config/swaylock/config"
check "dotfiles/.config/i3status/config"
check "dotfiles/.config/waybar/config"
check "dotfiles/.config/waybar/style.css"
check "dotfiles/.ssh/config"
check "dotfiles/.wezterm.lua"

printf "\nPassed: %d  Failed: %d\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
