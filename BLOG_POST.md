## dotfiles

Updated scripts are maintained at [github.com/davidemerson/dotfiles](https://github.com/davidemerson/dotfiles.git).

These dotfiles configure a workstation on Debian Linux, OpenBSD, or macOS from a single POSIX shell script. No Salt, Ansible, or other configuration management tools — just `sh provision.sh`. The script is idempotent and safe to re-run after pulling updates.

### how it works

The provisioning script detects the OS via `uname -s` and branches accordingly:

- **Debian Linux**: installs packages via `apt-get`, configures sway (Wayland), foot, waybar, wofi, swaylock. Auto-launches sway on tty1 via `.bashrc`.
- **OpenBSD**: installs packages via `pkg_add`, configures i3 (X11), st, dmenu, i3lock, i3status. Auto-launches X/i3 on ttyC0 via `.bashrc` → `startx` → `.xinitrc`.
- **macOS**: installs packages via Homebrew, deploys `.zshrc`, `.wezterm.lua`, `.gitconfig`. No window manager configuration.

#### os-conditional blocks

Some config files need different content per OS. Rather than maintaining separate files, we use simple markers:

```
# @@IF_OPENBSD@@
export EDITOR="${EDITOR:-nano}"
# @@END_IF@@
# @@IF_LINUX@@
export EDITOR="${EDITOR:-subl}"
# @@END_IF@@
```

At deploy time, `sed` strips blocks for other OSes and removes the marker comments, leaving a clean config file. This replaces the Jinja2/Salt templating from the earlier version of this project with zero dependencies.

#### file routing

Not every dotfile deploys on every OS. The provision script skips irrelevant configs:

- **Linux** gets sway, waybar, foot, swaylock, wofi configs. Skips i3.
- **OpenBSD** gets i3, i3status, `.xinitrc`. Skips sway, foot, waybar, wofi.
- **macOS** gets `.zshrc` and `.wezterm.lua`. Skips all window manager configs, `.bashrc`, and `.bash_profile` (macOS uses zsh).

### procedure

#### linux (debian)

VMWare Workstation settings (if applicable):
- Enable Virtualize IOMMU to prevent keyboard lag.
- Enable 3D Acceleration with ~2GB VRAM.
- Enable Enhanced Keyboard if available to avoid Windows lock conflicts.

Standard Debian installation, selecting Desktop, SSH Server, and Standard System Utilities. Then:

```
su -
apt update && apt install git
git clone https://github.com/davidemerson/dotfiles.git
cd dotfiles/
sh provision.sh
reboot
```

After reboot, log in on tty1. Sway launches automatically. `Mod4+Return` opens foot.

The script also sets the console font to Terminus 14 (visible briefly before sway takes over) and installs Sublime Text from the official apt repository.

#### openbsd

Standard OpenBSD installation. On smaller disks, ensure `/usr/local` has at least 2GB (the full install uses about 1.6GB in `/usr/local`).

```
pkg_add git
git clone https://github.com/davidemerson/dotfiles.git
cd dotfiles/
sh provision.sh
reboot
```

After reboot, log in on ttyC0. X and i3 launch automatically via `startx`. `Mod4+Return` opens st.

The script configures doas for the wheel group, adds the hostname to `/etc/hosts` (prevents slow DNS lookups), sets the UTF-8 locale for proper Unicode rendering in st/btop, and removes the default `/etc/i3/config` that conflicts with the user config.

**Why i3 instead of sway on OpenBSD?** OpenBSD on VMware arm64 uses a `simplefb` framebuffer with no DRM/GPU driver, which means sway (Wayland) can't create a rendering backend. i3 on X11 works out of the box. The i3 config mirrors the sway config — same keybindings, colors, gaps, workspaces.

#### macos

```
git clone https://github.com/davidemerson/dotfiles.git ~/dotfiles
cd ~/dotfiles
sh provision.sh
```

Run as your normal user, not root. The script installs Homebrew if missing, then installs CLI tools and WezTerm. Only relevant dotfiles are deployed — `.zshrc` (macOS uses zsh by default), `.gitconfig`, `.wezterm.lua`, `.ssh/config`.

### what gets installed

| Component | Linux | OpenBSD | macOS |
|-----------|-------|---------|-------|
| Window Manager | Sway (Wayland) | i3 (X11) | — |
| Terminal | foot | st | WezTerm |
| Status Bar | waybar | i3bar + i3status | — |
| Launcher | wofi | dmenu | — |
| Lock | swaylock | i3lock + xautolock | — |
| Volume | pamixer + wob | sndioctl | — |
| Privilege | sudo | doas | sudo |
| Browser | Firefox ESR | Firefox ESR | — |
| Email | neomutt + msmtp | neomutt + msmtp | neomutt + msmtp |
| Editor | micro, nano, Sublime Text | nano | micro, nano |
| Shell | bash | bash | zsh |
| Tools | htop, btop, nmap, screen, lsd | htop, btop, nmap, screen, lsd | htop, btop, nmap, lsd |
| Font | Berkeley Mono Variable (foot) | Berkeley Mono Variable (i3bar) | Berkeley Mono Variable (WezTerm) |

### keybindings

Consistent across sway (Linux) and i3 (OpenBSD):

| Key | Action |
|-----|--------|
| Mod4 + Return | Terminal (foot / st) |
| Mod4 + d | Launcher (wofi / dmenu) |
| Mod4 + z | Lock screen |
| Mod4 + Shift+q | Kill window |
| Mod4 + Shift+e | Exit (with confirmation) |
| Mod4 + Shift+s | Shutdown (with confirmation) |
| Mod4 + j/k/i/l | Focus left/down/up/right |
| Mod4 + Shift+j/k/i/l | Move window |
| Mod4 + h/v | Split horizontal/vertical |
| Mod4 + 1-0 | Switch workspace |
| Mod4 + Shift+1-0 | Move to workspace |
| Mod4 + m/n | Volume up/down |
| Mod4 + r | Enter resize mode |

### shell aliases

Set in `.bashrc` (Linux/OpenBSD) and `.zshrc` (macOS):

```
alias ls='lsd -laF'
alias ll='lsd -laF'
alias la='lsd -la'
alias top='btop'
```

### notes

#### mail secrets

Password credentials for neomutt/msmtp are stored in `~/.secrets/mailpass`, not in the repository.

#### vmware svga emulation

On Linux, sway launches with `WLR_NO_HARDWARE_CURSORS=1` in `.bashrc` to work around VMWare SVGA limitations. Remove this on bare metal.

#### windows lock command

If running VMWare on a Windows host, disable Win+L via registry:

`HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DisableLockWorkstation` set to `1`.

#### re-applying updates

```
cd /path/to/dotfiles
git pull
sh provision.sh
```

All operations are idempotent. Package managers skip installed packages. Files are overwritten with the current version. Services are configured with `|| true` guards.

### additional references

- [agung-satria/dotfiles](https://github.com/agung-satria/dotfiles)
- [sohcahtoa/dotfiles](https://github.com/sohcahtoa/dotfiles)
- [jcs on openbsd](https://jcs.org/)
- [daulton/dotfiles](https://daulton.ca/dotfiles/)
- [eradman/dotfiles](https://eradman.com/)
