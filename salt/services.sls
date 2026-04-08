{%- set os = grains['os'] -%}

{% if os == 'OpenBSD' %}
# Timezone
timezone_config:
  cmd.run:
    - name: ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    - unless: readlink /etc/localtime | grep -q UTC

# NTP (OpenBSD ntpd)
ntp_service:
  cmd.run:
    - name: rcctl enable ntpd && rcctl start ntpd
    - unless: rcctl check ntpd

{% else %}
# Timezone
timezone_config:
  timezone.system:
    - name: UTC
    - utc: True

# NTP
ntp_service:
  service.running:
    - name: systemd-timesyncd
    - enable: True

# Disable graphical login manager
gdm_service:
  service.disabled:
    - name: gdm
    - enable: False

{% endif %}

# Font cache (both OSes)
font_cache:
  cmd.run:
    - name: fc-cache -f
    - onlyif: command -v fc-cache
