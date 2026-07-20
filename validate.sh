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

printf "Core:\n"
check "provision.sh"

printf "\nShell:\n"
check "dotfiles/.bashrc"
check "dotfiles/.bash_profile"
check "dotfiles/.zshrc"
check "dotfiles/.gitconfig"
check "dotfiles/.ssh/config"
check "dotfiles/.config/git/allowed_signers"
check "dotfiles/.tmux.conf"
check "dotfiles/.config/fontconfig/fonts.conf"
check "dotfiles/.fonts/bmv.otf"
check "dotfiles/.icons/plan9/cursors/left_ptr"
check "dotfiles/.icons/plan9/index.theme"
check "dotfiles/.icons/default/index.theme"
check "dotfiles/.Xresources"
check "dotfiles/.config/dunst/dunstrc"
check "dotfiles/.local/bin/volnotify"
check "dotfiles/.local/bin/shot"
check "dotfiles/.local/bin/lock"
check "dotfiles/.local/bin/sysinfo"
check "dotfiles/.local/bin/workstation"
check "dotfiles/.config/workstation.conf"

printf "\nTheming (man/gtk/btop):\n"
check "dotfiles/.config/gtk-3.0/settings.ini"
check "dotfiles/.config/gtk-4.0/settings.ini"
check "dotfiles/.config/btop/btop.conf"
check "dotfiles/.config/btop/themes/nnix.theme"

printf "\nLinux (sway):\n"
check "dotfiles/.config/sway/config"
check "dotfiles/.config/waybar/config"
check "dotfiles/.config/waybar/style.css"
check "dotfiles/.config/waybar/loadgraph.sh"
check "dotfiles/.config/foot/foot.ini"
check "dotfiles/.config/swaylock/config"
check "dotfiles/.config/wofi/style.css"

printf "\nOpenBSD (i3):\n"
check "dotfiles/.config/i3/config"
check "dotfiles/.config/i3status/config"
check "dotfiles/.xinitrc"
check "st/config.h"
check "st/patches.h"
check "dmenu/config.h"
check "dmenu/patches.h"

printf "\nmacOS:\n"
check "dotfiles/.wezterm.lua"

printf "\nEditor:\n"
check "dotfiles/.issyrc"
check "dotfiles/.config/micro/settings.json"
check "dotfiles/.config/micro/bindings.json"

printf "\nPassed: %d  Failed: %d\n" "$pass" "$fail"
[ "$fail" -eq 0 ]
