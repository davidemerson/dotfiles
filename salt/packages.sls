# Core system packages
core_packages:
  pkg.latest:
    - pkgs:
      - curl
      - wget
      - git
      - sudo
      - ntpdate
      - build-essential
      - unzip

# Development tools
dev_packages:
  pkg.latest:
    - pkgs:
      - nano
      - micro
      - htop
      - nmap
      - screen

# Sway desktop environment
sway_packages:
  pkg.latest:
    - pkgs:
      - sway
      - swaybg
      - swaylock
      - swayidle
      - xwayland
      - waybar
      - wofi
      - wob
      - pamixer
      - foot

# Applications
app_packages:
  pkg.latest:
    - pkgs:
      - firefox-esr
      - neomutt
      - msmtp

# Development editors/IDEs
editor_packages:
  cmd.run:
    - name: |
        # Install Sublime Text repository key and package
        wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
        echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
        apt update && apt install -y sublime-text
    - unless: command -v subl

# VM tools (conditional)
vm_tools:
  pkg.latest:
    - pkgs:
      - open-vm-tools-desktop
    - onlyif: grep -q VMware /sys/class/dmi/id/sys_vendor
