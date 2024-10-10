/usr:
  file.recurse:
    - source: salt://usr/
    - user: root
    - group: root
    - file_mode: 755
    - makedirs: True
    - template: jinja
