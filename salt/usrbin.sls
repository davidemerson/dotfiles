/usr/bin:
  file.recurse:
    - source: salt://usr/bin/
    - user: root
    - group: wheel
    - file_mode: 755
    - makedirs: True
    - template: jinja
