if [ "$(tty)" = "/dev/tty1" ]; then
	exec WLR_NO_HARDWARE_CURSORS=1 sway
fi
