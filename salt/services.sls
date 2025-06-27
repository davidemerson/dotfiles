# Services configuration
# Set timezone
timezone_config:
  timezone.system:
    - name: UTC
    - utc: True

# Configure NTP synchronization properly
ntp_service:
  service.running:
    - name: systemd-timesyncd
    - enable: True

# Disable graphical login manager by default
gdm_service:
  service.disabled:
    - name: gdm
    - enable: False

# Font cache update
font_cache:
  cmd.run:
    - name: fc-cache -fv
    - runas: root
    - onchanges:
      - file: /usr/share/fonts/*
