# Dependencies

## Supported Platforms
- Debian Linux (13+)
- OpenBSD (7.8+)
- macOS (with Homebrew)

## Installed Software

### All Platforms
- **Shell**: bash (Linux/OpenBSD), zsh (macOS default)
- **Email**: neomutt + msmtp
- **Version Control**: git
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
- **Terminal**: st (suckless terminal)
- **Status Bar**: i3bar + i3status
- **Launcher**: dmenu
- **Lock Screen**: i3lock + xautolock
- **Volume**: sndioctl (built-in)
- **Privilege**: doas (configured for wheel group)
- **Browser**: Firefox ESR

### macOS
- **Terminal**: WezTerm (via Homebrew cask)
- **Editors**: micro
- **Package Manager**: Homebrew (installed automatically)
