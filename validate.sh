#!/bin/bash

# Dotfiles configuration validator
# Run this script to check if your dotfiles are properly configured

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_passed=0
check_failed=0

log_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((check_passed++))
}

log_fail() {
    echo -e "${RED}✗${NC} $1"
    ((check_failed++))
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo "Validating dotfiles configuration..."
echo

# Check Salt files
echo "Checking Salt configuration:"

for file in "salt/top.sls" "salt/base.sls" "salt/dotfiles.sls" "minion"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        log_pass "$file exists"
    else
        log_fail "$file missing"
    fi
done

echo

# Check essential dotfiles
echo "Checking essential dotfiles:"

required_files=(
    "salt/dotfiles/.bashrc"
    "salt/dotfiles/.gitconfig"
    "salt/dotfiles/.config/sway/config"
    "salt/dotfiles/.config/waybar/config"
    "salt/dotfiles/.config/sublime-text-3/Packages/User/Preferences.sublime-settings"
    "salt/dotfiles/.ssh/config"
)

for file in "${required_files[@]}"; do
    if [[ -f "$SCRIPT_DIR/$file" ]]; then
        log_pass "$file exists"
    else
        log_fail "$file missing"
    fi
done

echo

# Summary
echo "Validation complete:"
echo -e "  ${GREEN}Passed: $check_passed${NC}"
echo -e "  ${RED}Failed: $check_failed${NC}"

if [[ $check_failed -eq 0 ]]; then
    echo -e "\n${GREEN}All checks passed! Configuration looks good.${NC}"
    exit 0
else
    echo -e "\n${RED}Some checks failed. Please review the configuration.${NC}"
    exit 1
fi
