# Source ~/.profile first if it exists (e.g. a machine-local override). The
# repo ships no .profile — PATH and environment are set in .bashrc — so this
# is normally a no-op; .bashrc guards against being sourced twice.
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

# Then source .bashrc for prompt, aliases, sway/i3 autostart
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
