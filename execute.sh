#!/bin/bash

# Let's get the latest dotfiles from github, clean out the old states, and run salt.

git pull
rm -rf /srv/salt/
mkdir /srv/salt
cp -R salt/* /srv/salt/
salt-call --local state.highstate