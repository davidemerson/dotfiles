#!/bin/bash

# Let's get the latest dotfiles from github, clean out the old states, and run salt.

git pull
cp minion /etc/salt/minion
rm -rf /srv/salt/
mkdir -p /srv/salt
cp -R salt/* /srv/salt/
salt-call --local state.highstate
