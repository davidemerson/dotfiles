#!/bin/sh

# Dotfiles configuration validator
# Checks that required files exist in the repo

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

check_passed=0
check_failed=0

log_pass() {
    printf "${GREEN}✓${NC} %s\n" "$1"
    check_passed=$((check_passed + 1))
}

log_fail() {
    printf "${RED}✗${NC} %s\n" "$1"
    check_failed=$((check_failed + 1))
}

printf "Validating dotfiles configuration...\n\n"

# Check Salt files
printf "Checking Salt configuration:\n"

for file in "salt/top.sls" "salt/base.sls" "salt/packages.sls" "salt/services.sls" "salt/dotfiles.sls" "minion"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        log_pass "$file exists"
    else
        log_fail "$file missing"
    fi
done

printf "\n"

# Check essential dotfiles
printf "Checking essential dotfiles:\n"

for file in \
    "salt/dotfiles/.bashrc" \
    "salt/dotfiles/.gitconfig" \
    "salt/dotfiles/.config/sway/config" \
    "salt/dotfiles/.config/foot/foot.ini" \
    "salt/dotfiles/.config/swaylock/config" \
    "salt/dotfiles/.config/i3status/config" \
    "salt/dotfiles/.ssh/config"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        log_pass "$file exists"
    else
        log_fail "$file missing"
    fi
done

printf "\n"

# Summary
printf "Validation complete:\n"
printf "  ${GREEN}Passed: %d${NC}\n" "$check_passed"
printf "  ${RED}Failed: %d${NC}\n" "$check_failed"

if [ "$check_failed" -eq 0 ]; then
    printf "\n${GREEN}All checks passed.${NC}\n"
    exit 0
else
    printf "\n${RED}Some checks failed.${NC}\n"
    exit 1
fi
