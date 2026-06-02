#!/bin/sh
# Merge X resources (crisp Xft for Berkeley Mono) and tune input.
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
export XCURSOR_THEME=plan9      # plan9 cursor for X clients
export XCURSOR_SIZE=16
setxkbmap -option caps:escape   # Caps Lock -> Escape
xset r rate 250 30              # snappier key repeat
xset s 300 300                  # screensaver idle at 5 min -> xss-lock

# Wrap the session in a D-Bus session bus so dunst/notify-send work.
exec dbus-launch --exit-with-session i3
