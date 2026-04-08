# Dotfiles Dependencies

## Supported Platforms
- Debian Linux (12+)
- OpenBSD (7.8+)
- macOS (with Homebrew)

## Installed Software

### All Platforms
- **Shell**: bash
- **Email**: neomutt + msmtp
- **Version Control**: git
- **Tools**: nano, htop, nmap, lsd, curl, wget

### Linux + OpenBSD (Sway Desktop)
- **Compositor**: Sway, swaybg, swayidle, xwayland
- **Terminal**: foot
- **Launcher**: wofi
- **Lock screen**: swaylock
- **Browser**: Firefox ESR

### Linux Only
- **Status Bar**: waybar
- **Editors**: micro, Sublime Text
- **Volume**: pamixer + wob
- **VM Tools**: open-vm-tools-desktop (auto-detected)
- **Build**: build-essential

### OpenBSD Only
- **Status Bar**: swaybar (built-in) + i3status
- **Volume**: sndioctl (built-in)
- **Privilege**: doas (configured for wheel group)

### macOS Only
- **Terminal**: WezTerm (via Homebrew cask)
- **Editor**: micro
- **Package Manager**: Homebrew (installed automatically)
