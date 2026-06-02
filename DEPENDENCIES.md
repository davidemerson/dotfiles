# Dependencies

## Supported Platforms
- Debian Linux (13+)
- OpenBSD (7.8+)
- macOS (with Homebrew)

## Installed Software

### All Platforms
- **Font**: Berkeley Mono Variable NNIX (`~/.fonts/bmv.otf`) — set as the generic `monospace` family via `~/.config/fontconfig/fonts.conf`, so every fontconfig client inherits it.
- **Shell**: bash (Linux/OpenBSD), zsh (macOS default)
- **Editor**: [issy](https://github.com/davidemerson/issy) — built from source via Zig (0.15.2+) and installed to `/usr/local/bin/issy`. Set as `EDITOR` in `.bashrc`/`.zshrc`/`.muttrc`. Configured via `~/.issyrc`.
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
- **Launcher**: dmenu
- **Lock Screen**: i3lock + xautolock
- **Volume**: sndioctl (built-in)
- **Privilege**: doas (configured for wheel group)
- **Browser**: Firefox ESR (`firefox-esr`; `$mod+b`)

### macOS
- **Terminal**: WezTerm (via Homebrew cask)
- **Editors**: micro
- **Package Manager**: Homebrew (installed automatically)
