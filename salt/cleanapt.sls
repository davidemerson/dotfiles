cleanapt:
  cmd.run:
    - name: |
        apt-get -qqy autoremove
        apt-get -qqy autoclean
        apt-get -qqy clean
