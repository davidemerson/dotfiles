/home/david:
  file.recurse:
    - source: salt://dotfiles/
    - user: david
    - group: david
    - file_mode: 0600
    - makedirs: True
    - template: jinja