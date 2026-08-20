# Source ~/.profile first if it exists (e.g. a machine-local override), then
# ~/.bashrc for prompt, aliases and the sway/i3 autostart.
#
# Note that on Debian ~/.profile is NOT absent: adduser copies one from
# /etc/skel, and that stock file both sources ~/.bashrc itself *and* then
# unconditionally prepends ~/bin and ~/.local/bin to PATH. So .bashrc's own
# prepend guard runs before those appends and cannot see them, and ~/.local/bin
# ends up in PATH twice. Rather than fight over ordering with a file we do not
# own, just normalise PATH once at the end.
if [ -f "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi

# Collapse duplicate PATH entries, keeping the first (highest-priority)
# occurrence of each. Order is preserved; only later repeats are dropped.
__path_dedupe() {
    local old="$PATH" new="" dir
    local IFS=:
    for dir in $old; do
        [ -n "$dir" ] || continue
        case ":$new:" in
            *":$dir:"*) ;;
            *) new="${new:+$new:}$dir" ;;
        esac
    done
    PATH="$new"
}
__path_dedupe
unset -f __path_dedupe
export PATH
