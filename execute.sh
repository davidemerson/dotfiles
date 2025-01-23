#!/bin/ksh
# runs salt after copying some files to the right places.
cp minion /etc/salt/minion
rm -rf /srv/salt/
mkdir -p /srv/salt
cp -R salt/* /srv/salt/
salt-call --local state.highstate
fc-cache
