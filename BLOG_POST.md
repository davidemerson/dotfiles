## dotfiles

Updated scripts are maintained at [github.com/davidemerson/dotfiles](https://github.com/davidemerson/dotfiles.git).

A good guide on sway for Debian is available [here](https://wiki.debian.org/sway). These dotfiles support both Debian Linux and OpenBSD, detected automatically at provision time.

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

The provisioning script installs Salt via `pkg_add`, patches a known Salt URL handling bug, configures `doas` for the wheel group, and applies the full Salt highstate.

### what gets installed

Both platforms get Sway (Wayland compositor), foot (terminal), wofi (launcher), swaylock, Firefox ESR, neomutt + msmtp, and common tools (htop, nmap, screen, lsd, git, curl, wget).

Key differences:

| | Linux | OpenBSD |
|---|---|---|
| Status bar | waybar | swaybar + i3status |
| Volume | pamixer + wob | sndioctl |
| Privilege | sudo | doas |
| Editors | micro, nano, Sublime Text | nano |
| Shell | bash | bash (via pkg_add) |

Config files (sway, .bashrc) are Jinja2 templates rendered by Salt with OS-appropriate values - volume keybindings, shutdown commands, bar configuration, tty paths, and default editor all adapt automatically.

### notes

#### mail secrets

Password credentials for neomutt/msmtp are stored separately in `~/.secrets/mailpass`, not in the repository.

#### vmware svga emulation

Sway launches with `WLR_NO_HARDWARE_CURSORS=1 sway` in `.bashrc` to work around VMWare SVGA II adapter limitations. Remove this flag on bare metal.

#### windows lock command

If running VMWare on a Windows host, disable Win+L via registry:

`HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\DisableLockWorkstation` set to `1`.

#### autolaunch sway

The `.bashrc` conditionally launches sway on first login to the console - `/dev/tty1` on Linux, `/dev/ttyC0` on OpenBSD.

#### salt on openbsd

Salt 3007.x has a bug in `salt.utils.url.create()` that corrupts relative `salt://` paths. The provision script patches this automatically. Salt is also very slow on OpenBSD arm64 (~5 minutes per `salt-call` invocation due to Python startup and grains collection). Ensure the machine's hostname resolves locally (`/etc/hosts`) or grains collection will hang on DNS.

### additional references

- [agung-satria/dotfiles](https://github.com/agung-satria/dotfiles)
- [sohcahtoa/dotfiles](https://github.com/sohcahtoa/dotfiles)
- [jcs on openbsd](https://jcs.org/)
- [daulton/dotfiles](https://daulton.ca/dotfiles/)
- [eradman/dotfiles](https://eradman.com/)
