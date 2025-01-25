if [ "$(tty)" = "/dev/tty1" ]; then
	WLR_NO_HARDWARE_CURSORS=1 sway
fi
