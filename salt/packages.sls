{%- set os = grains['os'] -%}

# Core system packages
core_packages:
  pkg.installed:
    - pkgs:
      - curl
      - wget
      - git
      - unzip
{% if os == 'OpenBSD' %}
      - bash
{% else %}
      - sudo
      - ntpdate
      - build-essential
{% endif %}

# Development tools
dev_packages:
  pkg.installed:
    - pkgs:
      - nano
      - htop
      - nmap
      - screen
{% if os != 'OpenBSD' %}
      - micro
{% endif %}

# Sway desktop environment
sway_packages:
  pkg.installed:
    - pkgs:
      - sway
      - swaybg
      - swaylock
      - swayidle
      - xwayland
      - wofi
      - foot
      - lsd
{% if os == 'OpenBSD' %}
      - i3status
{% else %}
      - waybar
      - wob
      - pamixer
{% endif %}

# Applications
app_packages:
  pkg.installed:
    - pkgs:
      - firefox-esr
      - neomutt
      - msmtp

{% if os != 'OpenBSD' %}
# Sublime Text (Linux only)
editor_packages:
  cmd.run:
    - name: |
        wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null
        echo "deb https://download.sublimetext.com/ apt/stable/" | tee /etc/apt/sources.list.d/sublime-text.list
        apt-get update && apt-get install -y sublime-text
    - unless: command -v subl

# VM tools (auto-detected for VMware)
vm_tools:
  pkg.installed:
    - pkgs:
      - open-vm-tools-desktop
    - onlyif: grep -q VMware /sys/class/dmi/id/sys_vendor
{% endif %}
