# load Xresources file
xrdb -merge $HOME/.Xresources &

# autolock after 10min
exec --no-startup-id xautolock -time 10 -locker 'i3lock -f -c 303030'

# no more bells
xset b off &

# run i3
exec i3
