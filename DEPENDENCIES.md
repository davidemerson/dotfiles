# Dependencies

## Supported Platforms
- Debian Linux (13+)
- OpenBSD (7.8+)
- macOS (with Homebrew)

## Installed Software

### All Platforms
- **Font**: Berkeley Mono Variable NNIX (`~/.fonts/bmv.otf`) — set as the generic `monospace` family via `~/.config/fontconfig/fonts.conf`, so every fontconfig client inherits it.
- **Cursor** (Linux/OpenBSD): [plan9 Xcursor theme](https://github.com/wintermute-cell/xcursor-plan9) vendored at `~/.icons/plan9`, set default via `~/.icons/default` + `Xcursor.theme` (X11) and `seat xcursor_theme` (sway/Wayland); `XCURSOR_THEME`/`SIZE` exported in the session.
- **Shell**: bash (Linux/OpenBSD), zsh (macOS default)
- **Editor**: [issy](https://github.com/davidemerson/issy) — built from source via Zig (0.15.2+) and installed to `/usr/local/bin/issy`. Set as `EDITOR` in `.bashrc`/`.zshrc`/`.muttrc`. Configured via `~/.issyrc`. Re-running `provision.sh` compares the installed commit (`issy --version`) against upstream `HEAD` and rebuilds when a newer one exists (or when it stops linking after an OpenBSD upgrade).
- **Email**: neomutt + msmtp
- **Version Control**: git
- **Multiplexer**: tmux (in base on OpenBSD; via apt/brew elsewhere) — config at `~/.tmux.conf`
- **System fetch**: [pfetch](https://github.com/dylanaraps/pfetch) — minimal, dependency-free; runs on interactive shell login (outside tmux)
- **Tools**: nano, htop, btop, nmap, lsd, curl, wget

### Linux (Sway Desktop)
- **Compositor**: Sway, swaybg, swayidle, xwayland
- **Terminal**: foot
- **Status Bar**: waybar
- **Launcher**: wofi
- **Lock Screen**: swaylock
- **Volume**: pamixer + wob
- **Editors**: micro, Sublime Text
- **Browser**: Firefox ESR
- **VM Tools**: open-vm-tools-desktop (auto-detected)
- **Build**: build-essential
- **Console Font**: Terminus 14

### OpenBSD (i3 Desktop)
- **Window Manager**: i3
- **Terminal**: st (suckless) — built from [st-flexipatch](https://github.com/bakkeby/st-flexipatch) (pinned) with `st/config.h` + `st/patches.h`. Patches: clipboard (selection auto-copies to system CLIPBOARD), keyboard-select (mouseless copy), scrollback + mouse wheel, anysize, bold-is-not-bright, boxdraw. Falls back to the packaged `st` (which also provides terminfo) if the build fails.
- **Status Bar**: i3bar + i3status
- **Launcher**: dmenu — built from [dmenu-flexipatch](https://github.com/bakkeby/dmenu-flexipatch) (pinned) with `dmenu/config.h` + `dmenu/patches.h`: fuzzy match + highlight, case-insensitive, centered, line-height padding, border. Packaged `dmenu` is the fallback.
- **Notifications**: dunst (`~/.config/dunst/dunstrc`, palette-themed); `$mod+m/n/Shift+m` volume changes show an OSD via `~/.local/bin/volnotify`
- **Screenshots**: scrot + xclip via `~/.local/bin/shot` (`Print`/`$mod+p` full, `$mod+Shift+p` region) → saved to `~/pictures/screenshots` and copied to clipboard
- **Clipboard history**: clipmenu (`clipmenud` daemon; `$mod+c` picks via dmenu)
- **Lock Screen**: `~/.local/bin/lock` (scrot → ImageMagick pixelate → i3lock); triggered by xss-lock (X-screensaver idle) and xautolock; `$mod+z` manual
- **X resources**: `~/.Xresources` (crisp Xft) merged in `.xinitrc`; Caps→Escape, key-repeat tuning
- **Volume**: sndioctl (built-in)
- **Privilege**: doas (configured for wheel group)
- **Browser**: Firefox ESR (`firefox-esr`; `$mod+b`)

### macOS
- **Terminal**: WezTerm (via Homebrew cask)
- **Editors**: micro
- **Package Manager**: Homebrew (installed automatically)

### Theming (palette-wide rice)
- **Colored man/less**: `LESS_TERMCAP` in the shell rc (light-blue headings, navy/white standout) — all platforms
- **GTK** (Linux/OpenBSD): `~/.config/gtk-{3,4}.0/settings.ini` — dark theme preference + plan9 cursor
- **btop**: `~/.config/btop/themes/nnix.theme` (grayscale + navy/blue), selected in `btop.conf`
- **Firefox** (Linux/OpenBSD): minimal black `userChrome.css` + compact-dark `user.js` in `~/.config/firefox`; installed into each profile by `~/.local/bin/firefox-rice` (run once after Firefox's first launch)
