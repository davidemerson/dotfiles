# Workstation Configuration

Personal dotfiles managed with SaltStack for automated Linux workstation setup.

## Quick Start

1. Clone this repository:
   ```bash
   git clone <your-repo-url> /tmp/dotfiles
   cd /tmp/dotfiles
   ```

2. Run the provisioning script as root:
   ```bash
   sudo ./provision.sh
   ```

3. Follow the prompts to:
   - Set username for dotfile deployment
   - Configure hostname (optional)

## What Gets Installed

- **Desktop**: Sway (Wayland) with waybar, wofi launcher, swaylock
- **Terminal**: foot terminal emulator
- **Editors**: micro, nano, Sublime Text
- **Applications**: Firefox ESR, neomutt, git
- **System tools**: htop, nmap, screen, curl, wget

See [DEPENDENCIES.md](DEPENDENCIES.md) for complete list.

## Configuration Structure

```
salt/
├── top.sls           # State orchestration
├── base.sls          # Core system setup
├── packages.sls      # Package management
├── services.sls      # System services
├── dotfiles.sls      # User configuration
└── dotfiles/         # Actual dotfiles
    ├── .bashrc
    ├── .gitconfig
    ├── .config/
    │   ├── sway/
    │   ├── waybar/
    │   └── ...
    └── .ssh/
```

## Customization

1. Edit files in `salt/dotfiles/` to customize configurations
2. Modify `salt/packages.sls` to add/remove software
3. Update pillar data in the provision script for system-wide settings

## Manual Steps After Installation

1. Generate SSH keys: `ssh-keygen -t ed25519 -C "your-email@example.com"`
2. Configure git signing (if desired)
3. Set up email credentials for neomutt/msmtp

## Troubleshooting

- **Salt errors**: Check `/var/log/salt/minion` for detailed logs
- **Permission issues**: Ensure the script runs as root initially
- **Missing packages**: Verify internet connection and repository access

For more details: https://nnix.com/projects/dotfiles
