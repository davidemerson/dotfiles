## dotfiles

Updated scripts are maintained at [github.com/davidemerson/dotfiles](https://github.com/davidemerson/dotfiles.git).

These dotfiles support Debian Linux, OpenBSD, and macOS. A single POSIX shell script handles OS detection, package installation, service configuration, and dotfile deployment. No Salt, Ansible, or other configuration management tools required.

### procedure

#### linux (debian)

VMWare Workstation settings (if applicable):
- Enable Virtualize IOMMU to prevent keyboard lag.
- Enable 3D Acceleration with ~2GB VRAM.
- Enable Enhanced Keyboard if available to avoid Windows lock conflicts.

Standard Debian installation, selecting Desktop, GNOME, SSH Server, and Standard System Utilities. Then:

```
su -
apt update && apt install git
git clone https://github.com/davidemerson/dotfiles.git
cd dotfiles/
sh provision.sh
systemctl reboot
```

#### openbsd

Standard OpenBSD installation. The default auto-partition layout works fine on disks 30GB+. On smaller disks, ensure `/usr/local` has at least 2GB (packages land there) and `/usr` has at least 4GB. The full desktop install (sway, firefox-esr, etc.) uses about 1.6GB in `/usr/local`. Then:

```
pkg_add git
git clone https://github.com/davidemerson/dotfiles.git
cd dotfiles/
sh provision.sh
reboot
```

The provisioning script configures `doas` for the wheel group and adds the hostname to `/etc/hosts`.

#### macos

```
git clone https://github.com/davidemerson/dotfiles.git ~/dotfiles
cd ~/dotfiles
sh provision.sh
```

Run as your normal user, not root. The script installs Homebrew if missing, then installs packages and deploys dotfiles. Sway and Wayland configs are skipped on macOS — only relevant dotfiles (.bashrc, .gitconfig, .wezterm.lua, .ssh/config) are deployed.

### os-specific configuration

Config files use simple markers (`@@IF_LINUX@@`, `@@IF_OPENBSD@@`, `@@IF_MACOS@@`, `@@END_IF@@`) for OS-specific blocks. At deploy time, the provision script strips blocks for other OSes and keeps the current one. This replaces the Jinja2/Salt templating from the earlier version.

Key differences by OS:

| | Linux | OpenBSD | macOS |
|---|---|---|---|
| Status bar | waybar | swaybar + i3status | — |
| Volume | pamixer + wob | sndioctl | — |
| Shutdown | systemctl poweroff | doas shutdown -p now | — |
| Privilege | sudo | doas | sudo |
| Editor | Sublime Text | nano | nano |
| Sway TTY | /dev/tty1 | /dev/ttyC0 | — |

### notes

#### mail secrets

Password credentials for neomutt/msmtp are stored separately in `~/.secrets/mailpass`, not in the repository.

#### vmware svga emulation

Sway launches with `WLR_NO_HARDWARE_CURSORS=1 sway` in `.bashrc` to work around VMWare SVGA II adapter limitations. Remove this flag on bare metal.

#### windows lock command

If running VMWare on a Windows host, disable Win+L via registry:

`HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DisableLockWorkstation` set to `1`.

#### autolaunch sway

The `.bashrc` conditionally launches sway on first login to the console — `/dev/tty1` on Linux, `/dev/ttyC0` on OpenBSD. On macOS, no sway block is present.

#### idempotency

The script is safe to re-run. Package managers skip already-installed packages. Files are overwritten with the current version. Services are enabled idempotently. Pull the latest dotfiles and re-run `sh provision.sh` to apply updates.

### additional references

- [agung-satria/dotfiles](https://github.com/agung-satria/dotfiles)
- [sohcahtoa/dotfiles](https://github.com/sohcahtoa/dotfiles)
- [jcs on openbsd](https://jcs.org/)
- [daulton/dotfiles](https://daulton.ca/dotfiles/)
- [eradman/dotfiles](https://eradman.com/)
