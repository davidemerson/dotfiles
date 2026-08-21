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

## Secrets, and how a bare machine gets them

Some things a machine needs at provision time cannot live in this repository,
because this repository is public. Right now that means the **Berkeley Mono**
font: a commercial face from U.S. Graphics under an LT-02 licence of "Personal"
classification, whose `.otf` carries the licensee's own licence ID in its `name`
table. Committing it republished a paid personal licence to everyone who cloned.
Anything else that needs the same treatment goes the same way from here.

### The constraint

A bare machine holds no credential, so it cannot authenticate to a secret
store. That is not an implementation detail to route around — it is the shape
of the problem, and it is why a hosted secret manager cannot serve a *first*
build. Every workable scheme reduces to the same thing: **one** secret supplied
by a human, from which everything else follows.

So the design goal is to make that one secret small enough for a person to
type — including through an IPMI virtual KVM, which on some of these machines
is the only console there is.

### How it works

One symmetrically-encrypted bundle, published at a fixed URL:

```
https://assets.nnix.com/provisioning/nnix-secrets.tar.gpg
```

`provision.sh` fetches it, asks once for a passphrase, and unpacks each file to
the destination named in `scripts/secrets.manifest`. **The URL is not a
secret** — it is in this public file by necessity, and nothing rests on it
being obscure. The passphrase is the entire security boundary, so it should
have real entropy behind it (the current one is six words, ~91 bits).

Passphrase sources, least interactive first:

| Source | For |
|---|---|
| `$NNIX_SECRETS_PASSPHRASE` | scripted / CI provisioning |
| `/etc/nnix/secrets-pass` (mode `0600`) | an established host that re-provisions unattended |
| prompt on `/dev/tty` | a human at a console, including over the KVM |

**Re-runs never prompt.** The digest of the last successfully-unpacked bundle
is recorded in `/var/lib/nnix/secrets.sha256`; if the fetched bundle matches,
the whole step is skipped in silence. A passphrase is only ever needed when the
bundle is genuinely new to the host. And nothing here is fatal — if the bundle
cannot be fetched or decrypted, provisioning says so plainly and carries on
with the fallbacks below.

### What's in it

| File | Why it can't be committed |
|---|---|
| `bmv.otf`, `BerkeleyMonoNNIX.psf.gz` | commercial font, licensed per person |
| `id_d_nnix.pem`, `id_d_nnix.pub` | the SSH identity used for GitHub auth **and** commit signing |
| `workstation.conf` | per-machine hosts and key for the `workstation` command |

The sealed copy of `id_d_nnix.pem` is the **passphrase-protected** one, and that
is deliberate. It means the bundle passphrase alone does not yield the key: an
attacker holding the ciphertext needs *both* it and the key's own passphrase.
Replacing it with a passphraseless copy for convenience would throw away the
only defence in depth this arrangement has, so don't.

Be clear-eyed about the tradeoff you are accepting by putting an identity key
here at all. The cryptography is not the risk — six words with this KDF is not
brute-forceable by anyone. The risk is that **a published ciphertext cannot be
un-published**: anyone who fetches the bundle keeps it forever, so a passphrase
that leaks years from now retroactively exposes the key, and rotating the
bundle does nothing for copies already taken. Treat the bundle passphrase as
being exactly as sensitive as the key inside it, and rotate the key itself if
the passphrase is ever in doubt.

### Where it's hosted

`assets.nnix.com` is a **bucket of its own**, deliberately not part of the
website:

| Piece | Value |
|---|---|
| Bucket | `assets.nnix.com` (us-east-1), **private**, public ACLs blocked |
| CloudFront | `E2HQGXXWKWBIQN`, TLS 1.2_2021, HTTP→HTTPS |
| Origin access | OAC `E3IO4U9OLVFCCM`; bucket policy scoped to that distribution ARN alone |
| Logging | enabled → `nnix.com-cdn-logs`, prefix `assets_nnix_com_` |

The bundle briefly lived under the website's own bucket. That worked, but its
survival depended on an `--exclude` pattern in the site's deploy workflow that
nobody would recognise as load-bearing. A separate bucket makes it
unreachable-by-accident rather than merely filtered.

It is **not** committed to the `nnix.com` repo either, though it would be
tracked neatly there. That repo is public, and a git commit is permanent: it
would be mirrored by every clone and fork and ingested by archives that crawl
public repos. An S3 object can be *deleted* — which is the only lever you have
if the passphrase is ever in doubt. Encrypted-at-rest is not a licence to
publish into immutable history.

Access logging is not boilerplate. This bundle contains an SSH identity key, and
that log is the only detection that exists for it being fetched. Worth reading
occasionally.

### Adding a secret

Add a line to `scripts/secrets.manifest` and re-seal. No code changes:

```
# name                     destination                                 mode
bmv.otf                    @@TREE@@/dotfiles/.fonts/bmv.otf            0644
BerkeleyMonoNNIX.psf.gz    @@TREE@@/scripts/BerkeleyMonoNNIX.psf.gz    0644
```

`@@TREE@@` is the repository root as `provision.sh` sees it, `@@HOME@@` is the
target user's home, and the fourth column is the owner (`@@USER@@` for the
target user; omit it for root). A `0600` mode also gets its parent directory
created `0700` — which `~/.ssh` needs, since ssh silently refuses a key whose
directory is group- or world-accessible.

A payload may have **more than one destination**: `authorized_keys` is
byte-for-byte the public key, so it is carried once and installed twice rather
than sealed as a second copy. Repeating a name whose source *differs* is a hard
error, since otherwise whichever line the loop read last would silently win.

### What belongs in the bundle — and what doesn't

This bundle answers exactly one question: **what does any machine built from
these dotfiles need that cannot be public?** It is not a backup of one host.
Those are different questions, and conflating them is how a shared artifact
every machine downloads fills up with one particular machine's state.

So it carries things belonging to the **user**, true on every machine they
build — the font, the SSH identity. It deliberately does not carry things
identifying a **machine**:

| Excluded | Why |
|---|---|
| ZeroTier `identity.secret` | two hosts sharing one identity collide and break the network for both |
| `/etc/ssh/ssh_host_*_key` | a shared host key lets either machine impersonate the other |
| `/etc/nnix/monitoring.conf` | wanted on some hosts, not most; the SNMP community lives in 1Password |
| `/etc/nnix/firewall.conf` | per-host, and its seeded defaults are usually right |

The cost of excluding them is a one-time manual step on the few hosts that want
them, against a shared artifact that stays honest about its purpose.

If a per-host secret is ever genuinely needed, it does **not** want a scoping
column here — it wants its own bundle. `$NNIX_SECRETS_URL` is already
overridable, so pointing one host at a different URL needs no code at all. Then, from a machine where every listed file is already in
place:

```
sh scripts/seal-secrets.sh
aws --profile <p> s3 cp nnix-secrets.tar.gpg \
    s3://assets.nnix.com/provisioning/nnix-secrets.tar.gpg \
    --content-type application/octet-stream \
    --cache-control "max-age=300, must-revalidate"
aws --profile <p> cloudfront create-invalidation \
    --distribution-id E2HQGXXWKWBIQN --paths "/provisioning/*"
```

Hosts pick the new bundle up on their next run, because its digest no longer
matches their recorded one.

`assets.nnix.com` is a **separate bucket** from the website, with its own
CloudFront distribution, certificate and access logging. That is deliberate:
the site's deploy cannot disturb the bundle *even in principle*, rather than
merely being filtered away from it. The bucket is private and readable only
through CloudFront via an Origin Access Control, so the object is reachable at
the URL and nowhere else. Downloads are logged to `nnix.com-cdn-logs` under the
`assets_nnix_com_` prefix — worth actually looking at occasionally, given what
the bundle contains.

### If the passphrase is lost, or compromised

**Lost.** The bundle is unrecoverable — that is what the KDF is for. Nothing is
fatal, though: every file in it still exists on the machines that already have
it. Re-seal from a host that does (`sh scripts/seal-secrets.sh` reads each file
from the destination the manifest names), publish, and pick a new passphrase.

**Compromised.** Treat everything in the bundle as exposed, because a published
ciphertext cannot be un-published — anyone who fetched it keeps it, and a new
passphrase does nothing for copies already taken. In order:

1. Delete the object so no *further* copies can be taken:
   `aws --profile <p> s3 rm s3://assets.nnix.com/provisioning/nnix-secrets.tar.gpg`
2. **Rotate the SSH key.** Generate a new one, add it to GitHub as both an
   authentication and a signing key, remove the old one there, and update
   `dotfiles/.config/git/allowed_signers`. The old key must be assumed usable by
   whoever holds the ciphertext and the passphrase.
3. Re-seal with a new passphrase and republish.
4. Check `nnix.com-cdn-logs` under `assets_nnix_com_` for who fetched the
   bundle and when. This is the only forensic trail there is.

The key's *own* passphrase buys time here rather than safety: it means the
bundle passphrase alone is not sufficient, so an attacker needs both. Do not
treat it as a reason to skip rotation.

### Why gpg and not age

`age` is the nicer tool and was the first choice. It is unusable here: it
**refuses** to read a passphrase from anything but `/dev/tty`, failing with
*"standard input is not a terminal"*, so it cannot decrypt during an unattended
provision. `gpg --batch --passphrase-fd 0` can, is already installed on every
platform this repo targets — no new dependency — and still prompts a human when
one is present. The bundle uses AES-256 with an iterated, salted SHA-512 S2K at
the maximum count, since a published ciphertext is one an attacker can grind
offline forever.

### If the bundle is unavailable

Resolution is first-hit-wins per file, so the bundle is an accelerator rather
than a hard dependency:

1. **already in the tree** — a previous run, or placed by hand;
2. **`$NNIX_ASSET_DIR/<file>`** — a checkout, a mounted volume, a USB stick,
   the BMC's virtual media;
3. **1Password**, via `op document get`, if this host has a service-account
   token (`$OP_SERVICE_ACCOUNT_TOKEN`, `/etc/nnix/op-token` or
   `/etc/openclaw/op-token`, mode `0600`) or an interactive `op` session.
   Retained as a last resort because it works where a token already exists; it
   cannot serve a first build, for the reason at the top of this section.

If nothing resolves, provisioning warns and continues. `fontconfig` falls back
to whatever monospace the system has, and console-setup is left alone rather
than pointed at a `FONT=` that does not exist. If you have no Berkeley Mono
licence, buy one at <https://usgraphics.com> or change the font name in
`dotfiles/.config/fontconfig/fonts.conf` and the configs listed under
Repository Structure.

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

1. **Usually automatic** — the SSH key ships in the encrypted bundle (see "Secrets, and how a bare machine gets them"), so unsealing puts it at `~/.ssh/id_d_nnix.pem` with the right mode and owner. Do this by hand only if you skipped the bundle. Place the SSH key at `~/.ssh/id_d_nnix.pem` (plus matching `.pub`). Both `.ssh/config` and `.gitconfig` reference that path for auth and commit signing — copy the key from another machine, or generate a new one and register it on GitHub as both an authentication key and a signing key. If you use a different key, edit `dotfiles/.gitconfig`, `dotfiles/.ssh/config`, and `dotfiles/.config/git/allowed_signers` to match before running `provision.sh`. If the private key has no sibling `.pub`, generate one (`ssh-keygen -y -f <key> > <key>.pub`) so `workstation` can tell when it's already loaded.
2. Fill in `~/.config/workstation.conf` if you want the `workstation` command.
3. Sign in to 1Password, then enable its browser integration in Chrome (Chrome is allow-listed by default).
4. If `provision.sh` warned that the secrets bundle could not be unsealed, re-run it with the passphrase to hand (see "Secrets, and how a bare machine gets them"), or set `NNIX_ASSET_DIR` to a directory holding the files. Everything works without them; it just won't look right.

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
├── .fonts/bmv.otf        # Berkeley Mono Variable NNIX (NOT tracked — sealed, see above)
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
