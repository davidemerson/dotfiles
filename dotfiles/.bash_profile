# Source .profile first (sets PATH on OpenBSD/macOS)
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

# Then source .bashrc for prompt, aliases, sway/i3 autostart
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
