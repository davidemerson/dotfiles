/etc:
  file.recurse:
    - source: salt://etc/
    - user: root
    - group: root
    - file_mode: 755
    - makedirs: True
    - template: jinja
