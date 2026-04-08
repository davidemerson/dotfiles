# Dotfiles Dependencies

## Supported Platforms
- Debian Linux (12+)
- OpenBSD (7.8+)
- Root access required for initial setup
- Internet connection for package installation

## Installed Software

### Both Platforms
- **Desktop**: Sway (Wayland compositor), swaybg, swaylock, swayidle
- **Terminal**: foot
- **Launcher**: wofi
- **Browser**: Firefox ESR
- **Email**: neomutt + msmtp
- **Version Control**: git
- **Shell**: bash
- **Tools**: nano, htop, nmap, screen, lsd, curl, wget

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

## Network Requirements
- NTP servers: pool.ntp.org
- Salt bootstrap from GitHub (Linux only)
- Package repository access
