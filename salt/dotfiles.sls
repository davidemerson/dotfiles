{% set username = salt['pillar.get']('username', 'default_user') %}

/home/{{ username }}:
  file.recurse:
    - source: salt://dotfiles/
    - user: {{ username }}
    - group: {{ username }}
    - file_mode: 0600
    - makedirs: True
    - template: jinja
