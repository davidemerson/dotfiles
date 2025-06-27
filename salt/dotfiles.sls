{% set username = salt['pillar.get']('username', 'default_user') %}
{% set home_dir = '/home/' + username %}

# Ensure user exists and has proper groups
user_{{ username }}:
  user.present:
    - name: {{ username }}
    - groups:
      - sudo
      - users
    - shell: /bin/bash
    - home: {{ home_dir }}
    - createhome: True

# Deploy dotfiles with proper ownership and permissions
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

# SSH directory permissions (more restrictive)
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
