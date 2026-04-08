{%- set username = salt['pillar.get']('username', 'default_user') -%}
{%- set home_dir = '/home/' + username -%}
{%- set os = grains['os'] -%}

# Ensure user group exists
user_group_{{ username }}:
  group.present:
    - name: {{ username }}

# Ensure user exists with proper groups
user_{{ username }}:
  user.present:
    - name: {{ username }}
    - gid: {{ username }}
    - groups:
{% if os == 'OpenBSD' %}
      - wheel
{% else %}
      - sudo
      - users
{% endif %}
{% if os == 'OpenBSD' %}
    - shell: /usr/local/bin/bash
{% else %}
    - shell: /bin/bash
{% endif %}
    - home: {{ home_dir }}
    - createhome: True
    - require:
      - group: user_group_{{ username }}

# Deploy dotfiles with proper ownership
dotfiles_deployment:
  file.recurse:
    - name: {{ home_dir }}
    - source: salt://dotfiles/
    - user: {{ username }}
    - group: {{ username }}
    - file_mode: 644
    - dir_mode: 755
    - makedirs: True
    - template: jinja
    - require:
      - user: user_{{ username }}

# SSH directory permissions (restrictive)
ssh_directory:
  file.directory:
    - name: {{ home_dir }}/.ssh
    - user: {{ username }}
    - group: {{ username }}
    - mode: 700
    - require:
      - file: dotfiles_deployment

# SSH config permissions
ssh_config:
  file.managed:
    - name: {{ home_dir }}/.ssh/config
    - source: salt://dotfiles/.ssh/config
    - user: {{ username }}
    - group: {{ username }}
    - mode: 600
    - require:
      - file: ssh_directory
