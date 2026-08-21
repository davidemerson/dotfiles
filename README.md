# Workstation Dotfiles

Personal workstation configuration for **Debian Linux**, **OpenBSD**, and **macOS**.

A single POSIX shell script handles OS detection, package installation, service configuration, and dotfile deployment. No Salt, Ansible, or other configuration management tools required. The script is idempotent, safe to re-run after pulling updates.

Full documentation: https://nnix.com/projects/dotfiles

## Quick Start

### Linux (Debian)

```
su -
apt update && apt install git
git clone https://github.com/davidemerson/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
sh provision.sh
```

On a server, or to be explicit about it:

```
sh provision.sh --headless
```

### OpenBSD

```
pkg_add git
git clone https://github.com/davidemerson/dotfiles.git /tmp/dotfiles
cd /tmp/dotfiles
sh provision.sh    # as root
```

### macOS

```
git clone https://github.com/davidemerson/dotfiles.git ~/dotfiles
cd ~/dotfiles
sh provision.sh    # as your normal user
```

On Linux/OpenBSD the script prompts for the username to provision (creating it if needed, adding it to sudo/wheel, and setting bash as the login shell) and for a hostname. Reboot when it finishes.

## The font is not in this repo

Everything here renders in **Berkeley Mono Variable NNIX**, and that font is
**deliberately absent** from the repository. It is a commercial face from
U.S. Graphics under an LT-02 licence of "Personal" classification, and the
`.otf` binary carries the licensee's own licence ID in its `name` table.
Committing it would republish a paid personal licence to everyone who clones,
so it is fetched at provision time instead.

Two files are affected:

| Path | What it is |
|---|---|
| `dotfiles/.fonts/bmv.otf` | the vector face — st, dmenu, foot, waybar, sway, Sublime, issy |
| `scripts/BerkeleyMonoNNIX.psf.gz` | the 8x16 console bitmap rasterized from it |

`provision.sh` resolves each one in order, first hit wins:

1. **already in the tree** — a previous run, or dropped in by hand;
2. **`$NNIX_ASSET_DIR/<file>`** — a checkout, a mounted volume, a USB stick.
   This is the unattended path: it needs no 1Password session, so it is what
   to use for headless or scripted provisioning;
3. **1Password**, via `op document get` — but only if this host has a
   credential, and *where that credential comes from is the whole trick*:
   - a **service-account token**, read from `$OP_SERVICE_ACCOUNT_TOKEN` or,
     failing that, from **`/etc/nnix/op-token`** or `/etc/openclaw/op-token`
     (root-only, mode `0600`; a looser mode is ignored with a warning). `op`
     then runs directly, because a service account has no user session to
     attach to. **The file is not a nicety.** The documented way to run this
     script is `su -` (or `sudo`), and *both reset the environment* — an
     exported `OP_SERVICE_ACCOUNT_TOKEN` does **not** survive into the script.
     Either put it in the file, or pass it explicitly:
     `sudo -E sh provision.sh`, or `sudo OP_SERVICE_ACCOUNT_TOKEN=… sh provision.sh`;
   - with **no token at all**, it falls back to the invoking human's own
     1Password session via `$SUDO_USER`, since `op` then has to reach the
     desktop app and root cannot.

   Document titles default to `Berkeley Mono Variable NNIX` and `Berkeley Mono
   NNIX console PSF`, overridable with `NNIX_FONT_OP_ITEM` and
   `NNIX_CONSOLE_FONT_OP_ITEM`. No `--vault` is passed, so the documents
   resolve from whichever vaults the caller can see.

**Mind the bootstrap order.** A brand-new machine has no token file *and* no
signed-in `op`, so 1Password cannot help with the very first build of a host —
that one is an `NNIX_ASSET_DIR` (or hand-placement) job, and it always will be.
What 1Password buys you is that every *later* rebuild of an established host is
self-service. Do not read step 3 as "provisioning fetches the font from
nowhere"; read it as "a host that has been given a credential can re-fetch its
own assets".

**None of this is fatal.** If no source resolves, provisioning says so and
carries on: fontconfig falls back to whatever monospace the system has, and
console-setup is left entirely alone rather than pointed at a font file that
does not exist.

To populate 1Password the first time, from a machine that already has the
font and a signed-in `op` (add `--vault <name>` to place them somewhere
specific):

```
op document create ~/.fonts/bmv.otf \
    --title "Berkeley Mono Variable NNIX"
op document create scripts/BerkeleyMonoNNIX.psf.gz \
    --title "Berkeley Mono NNIX console PSF"
```

To re-upload after `scripts/build-console-font.sh` regenerates the bitmap, use
`op document edit "<title>" <file>` rather than `create`, so the item keeps its
identity.

If you have no Berkeley Mono licence, either buy one at
<https://usgraphics.com> or change the font name in
`dotfiles/.config/fontconfig/fonts.conf` and the handful of configs listed
under Repository Structure.

## What Gets Installed

Everything in the desktop rows below is skipped on a **headless** Linux host —
see [Headless hosts](#headless-hosts-linux).

| Component | Linux (Debian) | OpenBSD | macOS |
|-----------|---------------|---------|-------|
| Window Manager | Sway (Wayland) | i3 (X11) | |
| Greeter | greetd + tuigreet | xenodm | |
| Terminal | foot | st (patched) | WezTerm |
| Status Bar | waybar | i3bar + i3status | |
| Launcher | wofi | dmenu (patched) | |
| Lock Screen | swaylock | i3lock via `lock` script | |
| Notifications | mako | dunst | |
| Volume | pamixer + wob | sndioctl via `volnotify` | |
| Privilege | sudo | doas | sudo (built-in) |
| Browser | Google Chrome | Chromium | |
| Editor | issy (default), micro, nano, Sublime Text | issy (default), nano | issy (default), micro, nano |
| Shell | bash | bash (pkg_add) | zsh (default) |
| Multiplexers | tmux, herdr | tmux (base) | tmux, herdr |
| Remote shell | mosh | mosh | mosh |
| Fetch | pfetch + sysinfo | pfetch + sysinfo | pfetch + sysinfo |
| Password manager | 1Password + CLI | | 1Password + CLI |
| Notes | Joplin | | Joplin |
| Tasks | Todoist | | Todoist |
| Mail | Fastmail | | Fastmail |
| Media | VLC, Audacity | VLC, Audacity | VLC, Audacity |
| Meetings | Zoom | | Zoom |
| Git GUI | GitHub Desktop (community) | | GitHub Desktop |
| Networking | ZeroTier | | |
| AI CLI | Claude Code | | Claude Code |
| Clipboard | wl-clipboard + cliphist | clipmenu | |
| Firmware / ECC | fwupd, rasdaemon | | |
| Smart card | pcscd + libccid + opensc | | |
| Tools | htop, btop, nmap, screen, lsd, ethtool | htop, btop, nmap, screen, lsd | htop, btop, nmap, lsd |
| Font | Berkeley Mono | Berkeley Mono | Berkeley Mono |

## How It Works

### OS-Conditional Config Files

Files that need OS-specific lines use simple markers. From `.bashrc`:

```
# @@IF_OPENBSD@@
if [ "$(tty)" = "/dev/ttyC0" ]; then
	startx
fi
# @@END_IF@@
# @@IF_LINUX@@
if [ "$(tty)" = "/dev/tty1" ]; then
	WLR_NO_HARDWARE_CURSORS=1 sway
fi
# @@END_IF@@
```

At deploy time, `provision.sh` strips blocks for other OSes via `sed`, keeping only the current OS's blocks. A `@@HOME@@` marker is replaced with the target user's home directory. No template engine required.

### issy (default editor)

`provision.sh` builds [issy](https://github.com/davidemerson/issy) from source and installs it to `/usr/local/bin/issy`. Zig 0.15.x is required (0.16+ breaks the build), so provisioning verifies any zig already on PATH and otherwise installs a pinned one: `zig@0.15` via Homebrew on macOS, `pkg_add` on OpenBSD, or the official 0.15.2 tarball on Linux. `.bashrc` and `.zshrc` set issy as `EDITOR`. The step is idempotent: re-runs compare the installed commit (`issy --version`) against upstream `HEAD` and rebuild only when upstream is newer (or the binary stops linking after an OpenBSD `sysupgrade`). If Homebrew already manages issy on macOS, brew keeps ownership and the script just upgrades it.

### Patched st and dmenu (OpenBSD)

The stock st/dmenu packages stay installed as fallbacks (and for terminfo), but the binaries are replaced with builds from [st-flexipatch](https://github.com/bakkeby/st-flexipatch) and [dmenu-flexipatch](https://github.com/bakkeby/dmenu-flexipatch), pinned to specific commits, using the `st/` and `dmenu/` headers in this repo. st gets clipboard sync, keyboard-select, scrollback with mouse wheel, anysize, bold-is-not-bright, and boxdraw; dmenu gets fuzzy match with highlighting, case-insensitivity, centering, line-height padding, and a border. Rebuilds trigger on commit change, OS release change, `ldd` failure, or when the on-disk binary is not our build.

### workstation (mosh into the admin box)

`~/.local/bin/workstation` moshes into the admin workstation: it loads the SSH
key into the agent, probes the primary overlay path, falls back to the
secondary automatically (fallback is optional), and `exec`s mosh. Where it
points lives in `~/.config/workstation.conf` (labels, hosts, ssh aliases,
user, key) — the file is seeded once by `provision.sh` and never overwritten
on re-runs, so each machine can point at a different box. The tracked conf is
intentionally blank (this repo is public); fill in real values per machine —
the script refuses to run until you do. `workstation -h` shows the configured
paths; `workstation <label>` forces one.

### System Configuration (Linux/OpenBSD)

- **sshd**: key-only auth (`PasswordAuthentication no`, `KbdInteractiveAuthentication no`); the candidate config is validated with `sshd -t` before replacing the real one.
- **Timezone**: `America/New_York` (US Eastern, EST/EDT with auto-DST) on both. The waybar UTC clock uses an explicit override, so it still shows UTC alongside the Eastern clock.
- **NTP (Linux)**: systemd-timesyncd pinned to pool servers with a cloudflare fallback.
- **NTP (OpenBSD)**: `/etc/ntpd.conf` with pool + cloudflare + the vmt0 host-time sensor + HTTPS constraints, and `ntpd -s` to step at boot. A clock-guard cron job (every 10 minutes) restarts ntpd with an `rdate` step if the vmt0 sensor shows more than 10 seconds of drift, since a running OpenNTPD only slews.
- **OpenBSD extras**: doas for wheel (`permit persist :wheel`), noatime on all FFS partitions, xenodm enabled (Xorg needs root aperture access on VMware, no DRM), xconsole disabled, solid black greeter background, Spleen 8x16 console font where supported, and a VMware Xorg snippet with a 4K default mode.
- **Linux extras**: Berkeley Mono console font (rasterized from `bmv.otf`; see `scripts/build-console-font.sh`), gdm masked in favor of a **greetd + tuigreet** greeter (minimal TUI on vt7; sway starts via the `sway-session` login-shell wrapper), Sublime Text from the official apt repo, open-vm-tools-desktop when VMware is detected. Google Chrome is set as the default browser (update-alternatives for `x-www-browser`/`gnome-www-browser`, plus the per-user xdg default). **rasdaemon** is enabled to log ECC/MCE hardware error events (effective wherever the kernel EDAC layer exposes memory controllers; a no-op without ECC). **fwupd** is installed but firmware is never auto-flashed from the script — that is a deliberate, out-of-band action (`fwupdmgr refresh && fwupdmgr update`). **BlueZ** is installed and `bluetooth.service` enabled, so BT peripherals can actually pair; `/etc/bluetooth` is chmod'd to `0555` to match the unit's `ConfigurationDirectoryMode`, which the package otherwise contradicts with a `0755` directory and a warning on every start. Audio is **PipeWire** (PulseAudio masked), which also backs the **xdg-desktop-portal-wlr** ScreenCast portal used for screen sharing. Only the *sockets* are enabled, never `pipewire.service`/`pipewire-pulse.service`: an enabled service lands in `default.target`, which **every** login reaches — including a bare `ssh host true`, which then starts and tears down the whole audio stack for a session that will never play a sound (~23 log lines a connection, forwarded to the collector). Socket activation starts it on the first audio client instead, and `wireplumber` follows on its own (`BindsTo=`/`WantedBy=pipewire.service`). `filter-chain` and `mpris-proxy` ship `WantedBy=default.target` from Debian and are moved to `sway-session.target` for the same reason. When an **NVIDIA** GPU is detected, `contrib`/`non-free` are enabled and the proprietary driver replaces nouveau with `nvidia-drm modeset=1` (Wayland needs KMS) — that one needs a reboot. `/usr/sbin` is put back on the PATH for members of `sudo`.

### ssh-agent

`.bashrc` starts one shared per-user `ssh-agent` bound to a fixed socket in `$XDG_RUNTIME_DIR` and reuses it across every shell and the WM session it launches (macOS uses the launchd agent instead, so this is Linux/OpenBSD only). Without it a fresh Sway/i3 session has no agent, and `workstation` and SSH commit signing have nowhere to load the key. `workstation` also starts the same shared agent itself if one isn't already reachable.

### Clipboard (Linux)

On Sway, `wl-paste --primary --watch wl-copy` mirrors the primary selection into the clipboard, so selecting text in any terminal or app makes it pasteable everywhere with Ctrl+Shift+V (matching the OpenBSD st behavior). `wl-paste --watch cliphist store` keeps a history so a selection that clobbers a copied value can be recovered; `$mod+c` opens the history in a wofi picker.

### Desktop applications

- **1Password** (Linux apt repo with debsig-verify + CLI; macOS cask): `$mod+p` quick access, `$mod+Shift+p` main window, `$mod+Shift+z` lock. Chrome is in 1Password's default browser allowlist, so no custom allowlist is needed.
- **Todoist** (`$mod+t`), **Joplin** — installed as the official upstream AppImages under `/opt` with a `/usr/local/bin` wrapper + `.desktop` launcher on Linux; official casks on macOS.
- **Fastmail** (`$mod+e`) — official Flatpak (`com.fastmail.Fastmail`) on Linux via Flathub; official cask on macOS.
- **VLC**, **Audacity** — packaged on all platforms. **Zoom** — official `.deb` (no upstream apt repo; self-updates in-app) on Linux, cask on macOS. **GitHub Desktop** — *community* `shiftkey` build on Linux (GitHub ships no official Linux app); the genuine cask on macOS.

### System maintenance (Linux)

Beyond Debian's stock `fstrim`/`logrotate`/`fwupd-refresh` timers, `provision.sh` (`configure_maintenance`) adds:

- **Automatic updates** — `unattended-upgrades` installs all Debian updates (main + updates + security), removes unused deps and old kernels, and **never auto-reboots** — a needed reboot is only flagged, never forced.
- **needrestart** — after upgrades, reports which services need restarting and whether a kernel reboot is required (report-only; never auto-restarts a service).
- **Bounded logs** — the persistent journal is capped at `SystemMaxUse=1G`.
- **SMART monitoring** — `smartmontools` (`smartd`) watches drive health. The packaged unit runs `smartd -n $smartd_opts` against an `EnvironmentFile` that ships the variable commented out, so systemd logs *"Referenced but unset environment variable"* on every start; a drop-in sets it to smartd's own default (`--interval=1800`) rather than editing the conffile, which would prompt on upgrade.
- **fwupd metadata refresh, daily instead of hourly** — Debian's `fwupd-refresh.timer` is `OnCalendar=*-*-* *:00:00`. Firmware metadata does not change hourly, and each run wakes the daemon, which enumerates DRM devices — on an NVIDIA box that trips a driver `WARN` and a ~55-line stack trace into the log *every hour*. On an otherwise idle machine that is essentially the entire hourly log volume, forwarded verbatim to whatever collects syslog. A drop-in makes it daily. (Note the empty `OnCalendar=` first: it is a list, so without that the daily entry would be *added* to the hourly one, not replace it.) Nothing here ever auto-flashes firmware regardless — that stays a deliberate, out-of-band `fwupdmgr refresh && fwupdmgr update`.
- **No SysV shim for IPMI** — on a board with a BMC the kernel finds it by ACPI/DMI and loads `ipmi_si`/`ipmi_devintf`/`ipmi_msghandler` itself in early boot; `/dev/ipmi0` exists seconds before any init script could run. Debian's `openipmi` package nevertheless ships a SysV script that re-modprobes the same modules, logs `lsmod` errors of its own, and makes `systemd-sysv-generator` print a deprecation warning ("expect removal soon") three times per boot. `provision.sh` writes `/etc/modules-load.d/ipmi.conf` and disables the script. Gated on `/dev/ipmi0`, so a machine with no BMC is left alone.
- **Daily health check** — `/usr/local/bin/healthcheck` (from `scripts/healthcheck`) runs daily via `healthcheck.timer` (daily, not weekly: the state file is what monitoring reads, and a weekly result is stale six days out of seven) and logs a summary to the journal: reboot-required, disk usage, failed units, SMART/NVMe wear, ECC error counts, temperatures, pending updates. View with `journalctl -t healthcheck` (the target user is added to the `systemd-journal` group so no sudo is needed). Every probe is guarded, so it's a harmless no-op where a subsystem is absent (e.g. a VM).

### Headless hosts (Linux)

This is a workstation config, but the same repo provisions servers. `provision.sh` detects a **headless** host by reading the DRM connectors — if every connector reports `disconnected` (or the machine has none), nothing is attached — and then skips the parts that only make sense with a display:

- the desktop package set (sway, waybar, wofi, foot, greetd/tuigreet, mako, media apps, GTK/Qt theming, flatpak);
- the GUI applications (Chrome, Sublime Text, Zoom, GitHub Desktop, Todoist, Fastmail, Joplin desktop, and the 1Password *app* — the `op` CLI is still installed, since scripts need it);
- the greeter and the Berkeley Mono console font. This one matters: the greeter's `setfont` step exits `71/OSERR` on a machine with no framebuffer, which leaves `greetd.service` permanently failed and trips every health check on the box. Headless hosts boot to `multi-user.target` instead. On desktops the font load is now advisory (`ExecStartPre=-`), so a font that the kernel rejects can never stop the greeter from starting;
- every desktop dotfile. `deploy_dotfiles` additionally skips `sway`, `swaylock`, `waybar`, `wofi`, `foot`, `mako`, `gtk-3.0`, `gtk-4.0`, `fontconfig` and `sublime-text-3`, plus `.Xresources`, `.icons/` and `.local/bin/shot`. A headless host receives 15 files — shell, prompt, git, ssh, tmux, micro, btop, issy, `~/.local/bin` — and `.fonts/bmv.otf`, which stays because issy renders PDFs with it;
- the interactive hostname prompt. Renaming a host that other machines, certificates and monitoring refer to by name is not something to do by accident, and a bare `read` against a closed stdin would abort the run under `set -e`. Set `NNIX_HOSTNAME` to rename deliberately.

What a headless host *does* still get: timezone and NTP, the sshd hardening, the sysctl drop-in, unattended-upgrades with `Automatic-Reboot "false"`, needrestart in report-only mode, the 1 GB journal cap, SMART monitoring, the weekly healthcheck timer, zram, and the CLI tools (issy, pfetch, herdr, `op`, ZeroTier, Claude Code).

The tty autostart in `.bashrc` and `.xinitrc` is also now guarded by `command -v sway` / `command -v startx`. Both are `exec` calls: on a machine without the compositor installed they would have replaced the login shell with a failing command and dropped the console session.

Detection is by *attached display*, so a workstation provisioned with its monitor off or unplugged would be misread. Override it in either direction:

```sh
NNIX_HEADLESS=0 ./provision.sh   # force the full desktop
NNIX_HEADLESS=1 ./provision.sh   # force server mode
```

### Hardening & reliability (Linux)

`provision.sh` (`configure_hardening`) adds:

- **Host firewall** — nftables, default-deny inbound, allowing only loopback, established/related, ICMP, and the services actually used (SSH, mosh UDP 60000–61000, ZeroTier UDP 9993); outbound is open. Per-host exceptions go in **`/etc/nnix/firewall.conf`** (`EXTRA_TCP_PORTS`, `EXTRA_UDP_PORTS`, `TRUSTED_SUBNETS`), which is seeded once and never overwritten on re-provision. Three deliberate safeguards: the whole section is **skipped when ufw or firewalld is already active** (two firewall managers means the stricter one wins, silently); only the script's own `inet nnix` table is replaced, never `flush ruleset`, so ufw's and Docker's tables survive; and the **forward hook is left open when a container runtime is present** — Docker publishes ports via DNAT, which is *forwarded* rather than input, so a forward drop blackholes every container's networking. The rendered ruleset is `nft -c`-checked before it goes live.
- **Kernel/network hardening** — a conservative `sysctl` drop-in (`kptr_restrict`, `dmesg_restrict`, `yama.ptrace_scope`, no ICMP redirects or source-routing, syncookies, `fs.protected_*`).
- **zram** — compressed (zstd) swap sized to 50% of RAM, so memory spikes stay in RAM instead of hitting the (wear-limited) NVMe.
- **systemd-oomd** — graceful low-memory handling before the machine locks up.

Also in the desktop layer: **grim/slurp screenshots** (`Print` / `Shift+Print` via the Wayland-aware `shot`), **mako** notifications (palette-themed), **swayidle idle-lock** (swaylock at 1 h, display power-off at 2 h, and lock before sleep), **fzf + fd** shell integration, git **sane defaults** + **delta** diff pager, Qt apps forced dark via `adwaita-qt`/`adwaita-qt6`, and GTK4/libadwaita + the xdg portal + Chrome forced dark via a `prefer-dark` dconf default. A **waybar volume module** (right of memory) shows the level — scroll to change, left-click opens `pavucontrol` to choose the output device, right-click mutes.

### File Routing

Not every file deploys on every OS:

| File | Linux | OpenBSD | macOS |
|------|-------|---------|-------|
| `.bashrc`, `.bash_profile` | yes | yes | — |
| `.zshrc` | — | — | yes |
| `.wezterm.lua` | — | — | yes |
| `.xinitrc` | — | yes | — |
| `.config/sway/*`, `foot/*`, `waybar/*`, `wofi/*`, `swaylock/*`, `mako/*` | yes | — | — |
| `.config/i3/*`, `i3status/*`, `dunst/*`, `.local/bin/{lock,volnotify}` | — | yes | — |
| Everything else (git, ssh, tmux, issy, fonts, cursors, theming, `.Xresources`, `.local/bin/{workstation,shot,sysinfo}`) | yes | yes | yes |

`.config/workstation.conf` is seeded once and never overwritten, so per-machine values survive re-provisioning.

### Desktop Flow

- **Linux**: greetd + tuigreet greeter on vt7 → `/usr/local/bin/sway-session` (a login shell, so the session inherits `.bashrc`'s environment) launches sway → foot terminal, waybar, wofi. Because greetd execs that wrapper directly rather than going through a `wayland-sessions` .desktop file, the wrapper also does what a display manager would otherwise do: it exports `XDG_CURRENT_DESKTOP=sway` and `XDG_SESSION_TYPE=wayland`, and the sway config starts `sway-session.target`, which exists solely to pull in `xdg-desktop-autostart.target` — without it, the `.desktop` files apps install into `~/.config/autostart` (1Password, Tresorit) are generated into systemd units and then never started. On exit the wrapper stops those units again, since they are `PartOf=graphical-session.target` and nothing else would. Fallback: a tty1 console login runs the same wrapper from `.bashrc` when greetd isn't running.
- **OpenBSD**: xenodm greeter → `~/.xsession` launches i3 → st terminal, dmenu, i3bar (a ttyC0 console login still works: `.bashrc` runs `startx`, and `.xinitrc` mirrors `.xsession`)
- **macOS**: Open WezTerm → `.zshrc` loads prompt, aliases, environment

## Re-applying Changes

```
cd /path/to/dotfiles
git pull
sh provision.sh
```

Package installs, from-source builds, and file deploys are idempotent.

## Manual Steps After Installation

1. Place the SSH key at `~/.ssh/id_d_nnix.pem` (plus matching `.pub`). Both `.ssh/config` and `.gitconfig` reference that path for auth and commit signing — copy the key from another machine, or generate a new one and register it on GitHub as both an authentication key and a signing key. If you use a different key, edit `dotfiles/.gitconfig`, `dotfiles/.ssh/config`, and `dotfiles/.config/git/allowed_signers` to match before running `provision.sh`. If the private key has no sibling `.pub`, generate one (`ssh-keygen -y -f <key> > <key>.pub`) so `workstation` can tell when it's already loaded.
2. Fill in `~/.config/workstation.conf` if you want the `workstation` command.
3. Sign in to 1Password, then enable its browser integration in Chrome (Chrome is allow-listed by default).
4. If `provision.sh` warned that the font was unavailable, store it in 1Password (see "The font is not in this repo") and re-run — or set `NNIX_ASSET_DIR` to wherever you keep it and re-run. Everything works without it; it just won't look right.

## Keybindings (Sway / i3)

| Key | Action |
|-----|--------|
| Mod4 + Return | Terminal |
| Mod4 + d | Launcher (wofi / dmenu) |
| Mod4 + b | Browser (Chrome / Chromium) |
| Mod4 + t | Todoist |
| Mod4 + e | Fastmail |
| Mod4 + p | 1Password quick access (Sway) |
| Mod4 + Shift+p | 1Password main window (Sway) |
| Mod4 + c | Clipboard history picker (Sway) |
| Mod4 + z | Lock screen |
| Mod4 + Shift+z | 1Password lock (Sway) |
| Print / Shift+Print | Screenshot: full / region (Sway) |
| Mod4 + Shift+q | Kill window |
| Mod4 + w | Kill window (alias) |
| Mod4 + Shift+e | Exit (with confirmation) |
| Mod4 + Shift+s | Shutdown (with confirmation) |
| Mod4 + j/k/i/l | Focus left/down/up/right |
| Mod4 + Shift+j/k/i/l | Move window |
| Mod4 + h/v | Split horizontal/vertical |
| Mod4 + 1-0 | Switch workspace |
| Mod4 + Shift+1-0 | Move to workspace |
| Mod4 + Shift+space | Toggle floating |
| Mod4 + m/n | Volume up/down |
| Mod4 + r | Resize mode |
| Mod4 + Shift+c | Reload config |
| Mod4 + Shift+r | Reload config (alias) |

i3 (OpenBSD) additions:

| Key | Action |
|-----|--------|
| Mod4 + Shift+m | Mute toggle |
| Mod4 + c | Clipboard history (clipmenu) |
| Mod4 + ` | Scratchpad terminal |
| Print or Mod4 + p | Screenshot, full screen |
| Mod4 + Print or Mod4 + Shift+p | Screenshot, select region |

## Repository Structure

```
provision.sh              # Single provisioning script (POSIX sh)
validate.sh               # Check that all expected files exist
Makefile                  # make validate / make provision / make backup
DEPENDENCIES.md           # Platform and package inventory
scripts/healthcheck       # Weekly system health check (installed to /usr/local/bin, Linux)
st/config.h, patches.h    # Patched st build config (OpenBSD)
dmenu/config.h, patches.h # Patched dmenu build config (OpenBSD)
dotfiles/
├── .bashrc               # Bash: prompt, aliases, sway/startx autostart (OS-conditional)
├── .bash_profile         # Sources ~/.profile (if present) then .bashrc
├── .zshrc                # Zsh: same prompt and aliases (macOS)
├── .xinitrc              # xrdb, cursor, caps→escape, key repeat, dbus + i3 (OpenBSD)
├── .Xresources           # Crisp Xft rendering, plan9 cursor
├── .gitconfig            # Identity + SSH commit signing
├── .ssh/config           # GitHub host entry (auth key)
├── .tmux.conf            # tmux behavior + palette
├── .wezterm.lua          # WezTerm config (macOS)
├── .issyrc               # issy editor settings
├── .fonts/bmv.otf        # Berkeley Mono Variable NNIX (NOT tracked — fetched, see above)
├── .icons/plan9/         # plan9 cursor theme
├── .local/bin/           # workstation, lock, shot, volnotify, sysinfo
└── .config/
    ├── sway/, waybar/, foot/, swaylock/, wofi/, mako/   # Linux desktop (waybar/{load,net}graph.sh = load/net histograms)
    ├── i3/, i3status/                            # OpenBSD desktop
    ├── dunst/dunstrc                             # Notifications (OpenBSD)
    ├── fontconfig/fonts.conf                     # monospace = Berkeley Mono
    ├── gtk-3.0/, gtk-4.0/                        # Dark theme + cursor
    ├── btop/                                     # nnix theme
    ├── micro/, sublime-text-3/                   # Other editor settings
    ├── git/allowed_signers                       # SSH signature verification
    └── workstation.conf                          # Per-machine, seeded once
```

## After an OpenBSD `sysupgrade`

OpenBSD has no cross-release binary compatibility — a `sysupgrade` bumps the
base/Xenocara libraries, so binaries built from source (st, dmenu, issy) stop
loading (`ld.so: ... can't load library ...`; symptom: st/dmenu won't launch).
To recover:

```
doas pkg_add -u                          # resync packages to the new release
doas sh /path/to/dotfiles/provision.sh   # rebuilds st/dmenu/issy vs new libs
```

Note `pkg_add -u` also **reinstalls the stock `st`/`dmenu` packages over the
patched builds** (symptom: the font reverts from Berkeley Mono and the
clipboard/scrollback patches disappear) — so always run `provision.sh` *after*
`pkg_add -u`, not before. `provision.sh` is idempotent and rebuilds st/dmenu
when the build stamp's OS release (`uname -r`) changes, when the binary fails
`ldd`, **or when the on-disk binary isn't our build** (it checks that Berkeley
Mono is compiled in), so the re-run restores them. Reboot if the network or X
session did not come back cleanly from the upgrade.

## Troubleshooting

- **OpenBSD disk space**: `/usr/local` needs at least 2GB for packages
- **OpenBSD UTF-8**: The `.bashrc` sets `LANG=en_US.UTF-8` for st/btop
- **OpenBSD console font**: Cannot be changed on VMware arm64 (simplefb limitation)
- **Debian console font**: Berkeley Mono (NNIX) — an **8x16** PSF bitmap rasterized from `bmv.otf` via `scripts/build-console-font.sh`, installed to `/usr/share/consolefonts` and set through console-setup (`FONT=`). 8x16 is the classic Linux console cell; the earlier 15x29 build (the largest cell the console accepts) was unreadably large on a 4K panel. Two things make it actually stick. **One:** console-setup runs at sysinit, but where the GPU driver is a module — NVIDIA — fbcon is handed to the DRM framebuffer seconds later and that handover **resets every VT to the kernel's built-in font**, so `console-font.service` re-runs `setupcon` afterwards. Without it the setting silently applied to nothing except vt7, which only looked right because the greeter's own `greetd.service` drop-in re-runs `setfont` there. **Two:** `GRUB_GFXMODE` + `GRUB_GFXPAYLOAD_LINUX=keep` make the firmware hand over a native-resolution framebuffer instead of the 1024x768 one it defaults to — otherwise a 4K panel magnifies the early console 3.75x — and `fbcon=font:VGA8x16` pins the built-in font used by the messages that print *before* console-setup exists, which fbcon would otherwise render in TER16x32 on a large framebuffer. Net effect: one text size from power-on to the greeter. tuigreet's password mask is `•` (Berkeley Mono has no `※`/U+203B glyph)
- **macOS Homebrew**: Installed automatically if missing
- **macOS fonts**: CoreText doesn't scan `~/.fonts`, so the font is also copied to `~/Library/Fonts`

For more details: https://nnix.com/projects/dotfiles
